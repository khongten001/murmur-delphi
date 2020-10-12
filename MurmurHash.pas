{------------------------------------------------------------------------------
  MurmurHash was written by Austin Appleby, and is placed in the public
  domain. The author hereby disclaims copyright to this source code.

  Note - This code makes a few assumptions about how your machine behaves -

  1. We can read a 4-byte value from any address without crashing
  2. sizeof(int) == 4

  And it has a few limitations -

  1. It will not work incrementally.
  2. It will not produce the same results on little-endian and big-endian
     machines.

  Note :
    The x86 and x64 versions do _not_ produce the same results, as the
    algorithms are optimized for their respective platforms. You can still
    compile and run any of them on any platform, but your performance with the
    non-native version will be less than optimal.
}

unit MurmurHash;
interface
type
  UInt32Array  = array[0..8191] of UInt32;
  PUInt32Array = ^UInt32Array;
  UInt64Array  = array[0..4095] of UInt64;
  PUInt64Array = ^UInt64Array;

  TMurMur1 = class
  strict private
    const m: Cardinal = $c6a4a793;
    const r: Integer  = 16;
  public
    class function Hash(const Key; KeyLen: Integer; const Seed: UInt32): UInt32;
    class function HashAligned(const Key; KeyLen: Integer; const Seed: UInt32): UInt32;
  end;

  TMurMur2 = class
  strict private
  public
    class function Hash(const Key; KeyLen: Integer; const Seed: UInt32): UInt32;
    class function Hash64A(const Key; KeyLen: Integer; const Seed: UInt64): UInt64;
    class function Hash64B(const Key; KeyLen: Integer; const Seed: UInt64): UInt64;
    class function HashA(const Key; KeyLen: Integer; const Seed: UInt32): UInt32;
    class function HashNeutral(const Key; KeyLen: Integer; const Seed: UInt32): UInt32;
    class function HashAligned(const Key; KeyLen: Integer; const Seed: UInt32): UInt32;
  end;

  TMurMur3 = class
  strict private
  public
    class procedure Hash_x86_32(const Key; KeyLen: Integer; const Seed: UInt32; OutVal: Pointer);
    class procedure Hash_x86_128(const Key; KeyLen: Integer; const Seed: UInt32; OutVal: Pointer);
    class procedure Hash_x64_128(const Key; KeyLen: Integer; const Seed: UInt32; OutVal: Pointer);
  end;

(*
type
	TMurmur3 = class(TObject)
	protected
		class function HashData128_x86(const Key; KeyLen: LongWord; const Seed: LongWord): UInt64;
		class function HashData128_x64(const Key; KeyLen: LongWord; const Seed: LongWord): UInt64;

		class function HashData128(const Key; KeyLen: LongWord; const Seed: LongWord): UInt64;
		class function HashString128(const Key: UnicodeString; const Seed: LongWord): UInt64;
	public
		class function HashData32(const Key; KeyLen: LongWord; const Seed: LongWord): LongWord;
		class function HashString32(const Key: UnicodeString; const Seed: LongWord): LongWord;
	end;
*)
implementation
uses
  SysUtils, Math;

{ Utils }

function ROTL32(x: UInt32; n: Int8): UInt32; inline;
begin
  Result := (x shl n) or (x shr (32 - n));
end;

function ROTL64(x: UInt64; n: Int8): UInt64; inline;
begin
  Result := (x shl n) or (x shr (64 - n));
end;

{------------------------------------------------------------------------------
  Finalization mix - force all bits of a hash block to avalanche
}

function fmix32(h: UInt32): UInt32; inline;
begin
  h := h xor (h shr 16);
  h := h * $85ebca6b;
  h := h xor (h shr 13);
  h := h * $c2b2ae35;
  h := h xor (h shr 16);

  Result := h;
end;

function fmix64(h: UInt64): UInt64; inline;
begin
  h := h xor (h shr 33);
  h := h * $ff51afd7ed558ccd;
  h := h xor (h shr 33);
  h := h * $c4ceb9fe1a85ec53;
  h := h xor (h shr 33);

  Result := h;
end;

{------------------------------------------------------------------------------
  Block read - if your platform needs to do endian-swapping or can only
  handle aligned reads, do the conversion here
}

function getblock32(const ptr: PUInt32Array; idx: Integer): UInt32; inline;
begin
  Result := ptr[idx];
end;

function getblock64(const ptr: PUInt64Array; idx: Integer): UInt64; inline;
begin
  Result := ptr[idx];
end;

{ TMurMur1 }
// https://github.com/rurban/smhasher/blob/master/MurmurHash1.cpp
// objsize: 0-0x157: 343
class function TMurMur1.Hash(const Key; KeyLen: Integer; const Seed: UInt32): UInt32;
var
  hash,
  k:    Cardinal;
  data: PByteArray;
  i,
  len:  Integer;
begin
  hash := Seed xor (KeyLen * m);
  data := PByteArray(@Key);
  len  := KeyLen;
  i    := 0;

  while len >= 4 do
  begin
    k := PCardinal(@(data[i]))^;
    hash := hash + k;
    hash := hash * m;
    hash := hash xor (hash shr r);

    Inc(i, 4);
    Dec(len, 4);
  end;

  case len of
    3:
      hash := hash + (data[i + 2] shl r);
    2:
      hash := hash + (data[i + 1] shl 8);
    1:
    begin
      hash := hash + data[i];
      hash := hash * m;
      hash := hash xor (hash shr r);
    end;
  end;

  hash := hash * m;
  hash := hash xor (hash shr 10);
  hash := hash * m;
  hash := hash xor (hash shr 17);

  Result := hash;
end;

{------------------------------------------------------------------------------
  TMurmur1.HashAligned, by Austin Appleby

  Same algorithm as TMurmur1.Hash, but only does aligned reads - should be
  safer on certain platforms.

  Performance should be equal to or better than the simple version.
  objsize: 0x160-0x4e3: 899
}
class function TMurMur1.HashAligned(const Key; KeyLen: Integer; const Seed: UInt32): UInt32;
var
  hash,
  t, d:    Cardinal;
  data:    PByteArray;
  i,
  len,
  align,
  sl, sr,
  pack:    Integer;
begin
  hash  := Seed xor (KeyLen * m);
  data  := PByteArray(@Key);
  len   := KeyLen;
  i     := 0;
  align := UInt64(data) and 3;

  if (align > 0) and (len >= 4) then
  begin
    // Pre-load the temp registers
    t := 0;
    d := 0;

    case align of
      1: t := t or (data[i + 2] shl r);
      2: t := t or (data[i + 1] shl 8);
      3: t := t or data[i + 0];
    end;

    t := t shl (8 * align);
    Inc(i, 4 - align);
    Dec(len, 4 - align);

    sl := 8 * (4 - align);
    sr := 8 * align;

    // Mix
    while len >= 4 do
    begin
      d    := PCardinal(@(data[i]))^;
      t    := (t shr sr) or (d shl sl);
      hash := hash + t;
      hash := hash * m;
      hash := hash xor (hash shr r);
      t    := d;

      Inc(i, 4);
      Dec(len, 4);
    end;

    pack := Min(len, align);

    d := 0;

    case pack of
      3:
        d := d or (data[i + 2] shl r);
      2:
        d := d or (data[i + 1] shl 8);
      1:
        d := d or data[i];
      0:
      begin
        hash := hash + ((r shr sr) or (d shl sl));
        hash := hash * m;
        hash := hash xor (hash shr r);
      end;
    end;

    Inc(i, pack);
    Dec(len, pack);
  end else
  begin
    while len >= 4 do
    begin
      hash := hash + PCardinal(@(data[i]))^;
      hash := hash * m;
      hash := hash xor (hash shr r);

      Inc(i, 4);
      Dec(len, 4);
    end;
  end;

  // Handle tail bytes
  case len of
    3:
      hash := hash + (data[i + 2] shl r);
    2:
      hash := hash + (data[i + 1] shl 8);
    1:
    begin
      hash := hash + data[i];
      hash := hash * m;
      hash := hash xor (hash shr r);
    end;
  end;

  hash := hash * m;
  hash := hash xor (hash shr 10);
  hash := hash * m;
  hash := hash xor (hash shr 17);

  Result := hash;
end;

{ TMurMur2 }
// https://github.com/rurban/smhasher/blob/master/MurmurHash2.cpp
class function TMurMur2.Hash(const Key; KeyLen: Integer; const Seed: UInt32): UInt32;
begin

end;

class function TMurMur2.Hash64A(const Key; KeyLen: Integer; const Seed: UInt64): UInt64;
begin

end;

class function TMurMur2.Hash64B(const Key; KeyLen: Integer; const Seed: UInt64): UInt64;
begin

end;

class function TMurMur2.HashA(const Key; KeyLen: Integer; const Seed: UInt32): UInt32;
begin

end;

class function TMurMur2.HashNeutral(const Key; KeyLen: Integer; const Seed: UInt32): UInt32;
begin

end;

class function TMurMur2.HashAligned(const Key; KeyLen: Integer; const Seed: UInt32): UInt32;
begin

end;

{ TMurMur3 }
// https://github.com/rurban/smhasher/blob/master/MurmurHash3.cpp
class procedure TMurMur3.Hash_x86_32(const Key; KeyLen: Integer; const Seed: UInt32; OutVal: Pointer);
begin

end;

class procedure TMurMur3.Hash_x86_128(const Key; KeyLen: Integer; const Seed: UInt32; OutVal: Pointer);
begin

end;

class procedure TMurMur3.Hash_x64_128(const Key; KeyLen: Integer; const Seed: UInt32; OutVal: Pointer);
begin

end;

(*
uses
	SysUtils, Windows
{$IFDEF UnitTests}, MurmurHashTests{$ENDIF};

function LRot32(X: LongWord; c: Byte): LongWord;
begin
	Result := (X shl c) or (X shr (32-c));
end;

function WideCharToUtf8(const Source: PWideChar; nChars: Integer): AnsiString;
var
	strLen: Integer;
begin
	if nChars = 0 then
	begin
		Result := '';
		Exit;
	end;

	// Determine real size of destination string, in bytes
	strLen := WideCharToMultiByte(CP_UTF8, 0, Source, nChars, nil, 0, nil, nil);
	if strLen = 0 then
		RaiseLastOSError;

	// Allocate memory for destination string
	SetLength(Result, strLen);

	// Convert source UTF-16 string (UnicodeString) to the destination using the code-page
	strLen := WideCharToMultiByte(CP_UTF8, 0, Source, nChars, PAnsiChar(Result), strLen, nil, nil);
	if strLen = 0 then
		RaiseLastOSError;
end;

{ TMurmur3 }

{$OVERFLOWCHECKS OFF}
class function TMurmur3.HashData128(const Key; KeyLen: LongWord; const Seed: LongWord): UInt64;
begin
{$IFDEF CPUX64}
	Result := TMurmur3.HashData128_x64(Key, KeyLen, Seed);
{$ELSE}
	Result := TMurmur3.HashData128_x86(Key, KeyLen, Seed);
{$ENDIF}
end;

class function TMurmur3.HashData32(const Key; KeyLen: LongWord; const Seed: LongWord): LongWord;
var
	hash: LongWord;
	len: LongWord;
	k: LongWord;
	i: Integer;
	keyBytes: PByteArray;

const
	c1 = $cc9e2d51;
	c2 = $1b873593;
	r1 = 15;
	r2 = 13;
	m = 5;
	n = $e6546b64;
begin
{
	Murmur3 32-bit
		https://github.com/rurban/smhasher/blob/master/MurmurHash3.cpp
		http://code.google.com/p/smhasher/source/browse/
}
	keyBytes := PByteArray(@Key);

	// Initialize the hash
	hash := seed;
	len := KeyLen;

	i := 0;

	// Mix 4 bytes at a time into the hash
	while(len >= 4) do
	begin
		k := PLongWord(@(keyBytes[i]))^;

		k := k*c1;
		k := LRot32(k, r1);
		k := k*c2;

		hash := hash xor k;
		hash := LRot32(hash, r2);
		hash := hash*m + n;

		Inc(i, 4);
		Dec(len, 4);
	end;

	{	Handle the last few bytes of the input array
			Key: ... $69 $18 $2f
	}
	if len > 0 then
	begin
		Assert(len <= 3);
		k := 0;

		//Pack last few bytes into k
		if len = 3 then
			k := k or (keyBytes[i+2] shl 16);
		if len >= 2 then
			k := k or (keyBytes[i+1] shl 8);
		k := k or (keyBytes[i]);

		k := k*c1;
		k := LRot32(k, r1);
		k := k*c2;

		hash := hash xor k;
	end;

	// Finalization
	hash := hash xor keyLen;

	hash := hash xor (hash shr 16);
	hash := hash * $85ebca6b;
	hash := hash xor (hash shr 13);
	hash := hash * $c2b2ae35;
	hash := hash xor (hash shr 16);

	Result := hash;
end;
{$OVERFLOWCHECKS ON} 

class function TMurmur3.HashString128(const Key: UnicodeString; const Seed: LongWord): UInt64;
var
	s: AnsiString; //UTF-8 version of Key
begin
	s := WideCharToUtf8(PWideChar(Key), Length(Key));

	Result := TMurmur3.HashData128(Pointer(s)^, Length(s)*SizeOf(AnsiChar), Seed);
end;

class function TMurmur3.HashString32(const Key: UnicodeString; const Seed: LongWord): LongWord;
var
	s: AnsiString; //UTF-8 version of Key
begin
	s := WideCharToUtf8(PWideChar(Key), Length(Key));

	Result := TMurmur3.HashData32(Pointer(s)^, Length(s)*SizeOf(AnsiChar), Seed);
end;

class function TMurmur3.HashData128_x64(const Key; KeyLen: LongWord; const Seed: LongWord): UInt64;
begin
	raise Exception.Create('Not implemented');
end;

class function TMurmur3.HashData128_x86(const Key; KeyLen: LongWord; const Seed: LongWord): UInt64;
begin
	raise Exception.Create('Not implemented');
end;
*)

end.
