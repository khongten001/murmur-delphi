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

unit MurMurHash;
interface
type
  UInt32Array  = array[0..8191] of UInt32;
  PUInt32Array = ^UInt32Array;
  UInt64Array  = array[0..4095] of UInt64;
  PUInt64Array = ^UInt64Array;

  TMurMur1 = class
  strict private
    const m: UInt32 = $c6a4a793;
    const r: UInt32 = 16;
  public
    class function Hash(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
    class function HashAligned(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
  end;

  TMurMur2 = class
  strict private
  public
    class function Hash(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
    class function HashA(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
    class function Hash64A(const Key; KeyLen: UInt32; const Seed: UInt64): UInt64;
    class function Hash64B(const Key; KeyLen: UInt32; const Seed: UInt64): UInt64;
    class function HashNeutral(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
    class function HashAligned(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
  end;

  TMurMur3 = class
  strict private
  public
    class procedure Hash_x86_32(const Key; KeyLen: UInt32; const Seed: UInt32; OutVal: Pointer);
    class procedure Hash_x86_128(const Key; KeyLen: UInt32; const Seed: UInt32; OutVal: Pointer);
    class procedure Hash_x64_128(const Key; KeyLen: UInt32; const Seed: UInt32; OutVal: Pointer);
    class function Hash(const Key; KeyLen: UInt32; const Seed: UInt32): UInt64;
  end;

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

procedure mmix(var hash, k: UInt32; m, r: UInt32); inline;
begin
  k := k * m;
  k := k xor (k shr r);
  k := k * m;

  hash := hash * m;
  hash := hash xor k;
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
class function TMurMur1.Hash(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
var
  k:      UInt32;
  data:   PByteArray;
  i, len: Integer;
begin
  Result := Seed xor (KeyLen * m);
  data   := PByteArray(@Key);
  len    := KeyLen;
  i      := 0;

  while len >= 4 do
  begin
    k      := PUInt32(@(data[i]))^;
    Result := Result + k;
    Result := Result * m;
    Result := Result xor (Result shr r);

    Inc(i, 4);
    Dec(len, 4);
  end;

  case len of
    3:
      Result := Result + (data[i + 2] shl r);
    2:
      Result := Result + (data[i + 1] shl 8);
    1:
    begin
      Result := Result + data[i];
      Result := Result * m;
      Result := Result xor (Result shr r);
    end;
  end;

  Result := Result * m;
  Result := Result xor (Result shr 10);
  Result := Result * m;
  Result := Result xor (Result shr 17);
end;

{------------------------------------------------------------------------------
  TMurmur1.HashAligned, by Austin Appleby

  Same algorithm as TMurmur1.Hash, but only does aligned reads - should be
  safer on certain platforms.

  Performance should be equal to or better than the simple version.
  objsize: 0x160-0x4e3: 899
}
class function TMurMur1.HashAligned(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
var
  t, d:                        UInt32;
  data:                        PByteArray;
  i, len, align, sl, sr, pack: Integer;
begin
  Result := Seed xor (KeyLen * m);
  data   := PByteArray(@Key);
  len    := KeyLen;
  i      := 0;
  align  := UInt64(data[i]) and 3;

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
      d      := PUInt32(@(data[i]))^;
      t      := (t shr sr) or (d shl sl);
      Result := Result + t;
      Result := Result * m;
      Result := Result xor (Result shr r);
      t      := d;

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
        Result := Result + ((r shr sr) or (d shl sl));
        Result := Result * m;
        Result := Result xor (Result shr r);
      end;
    end;

    Inc(i, pack);
    Dec(len, pack);
  end else
  begin
    while len >= 4 do
    begin
      Result := Result + PUInt32(@(data[i]))^;
      Result := Result * m;
      Result := Result xor (Result shr r);

      Inc(i, 4);
      Dec(len, 4);
    end;
  end;

  // Handle tail bytes
  case len of
    3:
      Result := Result + (data[i + 2] shl r);
    2:
      Result := Result + (data[i + 1] shl 8);
    1:
    begin
      Result := Result + data[i];
      Result := Result * m;
      Result := Result xor (Result shr r);
    end;
  end;

  Result := Result * m;
  Result := Result xor (Result shr 10);
  Result := Result * m;
  Result := Result xor (Result shr 17);
end;

{ TMurMur2 }
// https://github.com/rurban/smhasher/blob/master/MurmurHash2.cpp
// objsize: 0-0x166: 358
class function TMurMur2.Hash(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
// 'm' and 'r' are mixing constants generated offline. They're not really 'magic', they just happen to work well.
const
  m: UInt32 = $5bd1e995;
  r: UInt32 = 24;
var
  k:      UInt32;
  data:   PByteArray;
  i, len: Integer;
begin
  // Initialize the hash to a 'random' value
  Result := Seed or KeyLen;
  data   := PByteArray(@Key);
  len    := KeyLen;
  i      := 0;

  // Mix 4 bytes at a time into the hash
  while len >= 4 do
  begin
    k := PUInt32(@(data[i]))^;

    mmix(Result, k, m, r);

    Inc(i, 4);
    Dec(len, 4);
  end;

  // Handle the last few bytes of the input array
  case len of
    3:
      Result := Result xor data[i + 2] shl 16;
    2:
      Result := Result xor data[i + 1] shl 8;
    1:
    begin
      Result := Result xor data[i];
      Result := Result * m;
    end;
  end;

  // Do a few final mixes of the hash to ensure the last few bytes are well-incorporated.
  Result := Result xor (Result shr 13);
  Result := Result * m;
  Result := Result xor (Result shr 15);
end;

{------------------------------------------------------------------------------
  TMurMur2.HashA, by Austin Appleby

  This is a variant of TMurMur2.Hash modified to use the Merkle-Damgard
  construction. Bulk speed should be identical to TMurMur2.Hash, small-key speed
  will be 10%-20% slower due to the added overhead at the end of the hash.

  This variant fixes a minor issue where null keys were more likely to
  collide with each other than expected, and also makes the function
  more amenable to incremental implementations.
}
class function TMurMur2.HashA(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
const
  m: UInt32 = $5bd1e995;
  r: UInt32 = 24;
var
  k, l, t: UInt32;
  data:    PByteArray;
  i, len:  Integer;
begin
  Result := Seed;
  data   := PByteArray(@Key);
  len    := KeyLen;
  l      := len;
  i      := 0;

  while len >= 4 do
  begin
    k := PUInt32(@(data[i]))^;

    mmix(Result, k, m, r);

    Inc(i, 4);
    Dec(len, 4);
  end;

  t := 0;

  case len of
    3:
      t := t xor (data[i + 2] shl 16);
    2:
      t := t xor (data[i + 1] shl 8);
    1:
      t := t xor data[i];
  end;

  mmix(Result, t, m, r);
  mmix(Result, l, m, r);

  Result := Result xor (Result shr 13);
  Result := Result * m;
  Result := Result xor (Result shr 15);
end;

{------------------------------------------------------------------------------
  TMurMur2.Hash64A, 64-bit versions, by Austin Appleby

  The same caveats as 32-bit TMurMur2.Hash apply here - beware of alignment
  and endian-ness issues if used across multiple platforms.

  64-bit hash for 64-bit platforms
  objsize: 0x170-0x321: 433
}
class function TMurMur2.Hash64A(const Key; KeyLen: UInt32; const Seed: UInt64): UInt64;
const
  m: UInt64 = $c6a4a7935bd1e995;
  r: UInt32 = 47;
var
  k:      UInt64;
  data:   PByteArray;
  i, len: Integer;
begin
  Result := Seed xor (KeyLen * m);
  data   := PByteArray(@Key);
  len    := KeyLen;
  i      := 0;

  while len >= 8 do
  begin
    k := PUInt64(@(data[i]))^;

    k := k * m;
    k := k xor (k shr r);
    k := k * m;

    Result := Result xor k;
    Result := Result * m;

    Inc(i, 8);
    Dec(len, 8);
  end;

  case len of
    7:
      Result := Result xor (UInt64(data[i + 6]) shl 48);
    6:
      Result := Result xor (UInt64(data[i + 5]) shl 40);
    5:
      Result := Result xor (UInt64(data[i + 4]) shl 32);
    4:
      Result := Result xor (UInt64(data[i + 3]) shl 24);
    3:
      Result := Result xor (UInt64(data[i + 2]) shl 16);
    2:
      Result := Result xor (UInt64(data[i + 1]) shl 8);
    1:
    begin
      Result := Result xor UInt64(data[i]);
      Result := Result * m;
    end;
  end;

  Result := Result xor (Result shr r);
  Result := Result * m;
  Result := Result xor (Result shr r);
end;

// 64-bit hash for 32-bit platforms
// objsize: 0x340-0x4fc: 444
class function TMurMur2.Hash64B(const Key; KeyLen: UInt32; const Seed: UInt64): UInt64;
const
  m: UInt32 = $5bd1e995;
  r: UInt32 = 24;
var
  h1, h2, k1, k2: UInt32;
  data:           PByteArray;
  i, len:         Integer;
begin
  h1   := UInt32(Seed) xor KeyLen;
  h2   := UInt32(Seed shr 32);
  data := PByteArray(@Key);
  len  := KeyLen;
  i    := 0;

  while len >= 8 do
  begin
    k1 := PUInt32(@(data[i]))^;
    k1 := k1 * m;
    k1 := k1 * (k1 shr r);
    k1 := k1 * m;
    h1 := h1 * m;
    h1 := h1 xor k1;
    Inc(i, 4);
    Dec(len, 4);

    k2 := PUInt32(@(data[i]))^;
    k2 := k2 * m;
    k2 := k2 xor (k2 shr r);
    k2 := k2 * m;
    h2 := h2 * m;
    h2 := h2 xor k2;
    Inc(i, 4);
    Dec(len, 4);
  end;

  if len >= 4 then
  begin
    k1 := PUInt32(@(data[i]))^;
    k1 := k1 * m;
    k1 := k1 xor (k1 shr r);
    k1 := k1 * m;
    h1 := h1 * m;
    h1 := h1 xor k1;
    Inc(i, 4);
    Dec(len, 4);
  end;

  case len of
    3:
      h2 := h2 xor (data[i + 2] shl 16);
    2:
      h2 := h2 xor (data[i + 1] shl 8);
    1:
    begin
      h2 := h2 xor data[i];
      h2 := h2 * m;
    end;
  end;

  h1 := h1 xor (h2 shr 18);
  h1 := h1 * m;
  h2 := h2 xor (h1 shr 22);
  h2 := h2 * m;
  h1 := h1 xor (h2 shr 17);
  h1 := h1 * m;
  h2 := h2 xor (h1 shr 19);
  h2 := h2 * m;

  Result := h1;
  Result := (Result shl 32) or h2;
end;

{------------------------------------------------------------------------------
  TMurMur2.HashNeutral, by Austin Appleby

  Same as TMurMur2.Hash, but endian- and alignment-neutral.
  Half the speed though, alas.
}
class function TMurMur2.HashNeutral(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
const
  m: UInt32 = $5bd1e995;
  r: UInt32 = 24;
var
  k:      UInt32;
  data:   PByteArray;
  i, len: Integer;
begin
  Result := Seed xor KeyLen;
  data   := PByteArray(@Key);
  len    := KeyLen;
  i      := 0;

  while len >= 4 do
  begin
    k := data[i];
    k := k or (data[i + 1] shl 8);
    k := k or (data[i + 2] shl 16);
    k := k or (data[i + 3] shl 24);

    k := k * m;
    k := k xor (k shr r);
    k := k * m;

    Result := Result * m;
    Result := Result xor k;

    Inc(i, 4);
    Dec(len, 4);
  end;

  case len of
    3:
      Result := Result xor data[i + 2] shl 16;
    2:
      Result := Result xor data[i + 1] shl 8;
    1:
    begin
      Result := Result xor data[i];
      Result := Result * m;
    end;
  end;

  Result := Result xor (Result shr 13);
  Result := Result * m;
  Result := Result xor (Result shr 15);
end;

{------------------------------------------------------------------------------
  TMurMur2.HashAligned, by Austin Appleby

  Same algorithm as TMurMur2.Hash, but only does aligned reads - should be safer
  on certain platforms.

  Performance will be lower than TMurMur2.Hash
}
class function TMurMur2.HashAligned(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
// MIX(h,k,m) { k *= m; k ^= k >> r; k *= m; h *= m; h ^= k; }
begin
(*
const uint32_t m = 0x5bd1e995;
  const int r = 24;

  const unsigned char * data = (const unsigned char * )key;

  uint32_t h = seed ^ len;

  int align = (uint64_t)data & 3;

  if(align && (len >= 4))
  {
    // Pre-load the temp registers

    uint32_t t = 0, d = 0;

    switch(align)
    {
      case 1: t |= data[2] << 16;
      case 2: t |= data[1] << 8;
      case 3: t |= data[0];
    }

    t <<= (8 * align);

    data += 4-align;
    len -= 4-align;

    int sl = 8 * (4-align);
    int sr = 8 * align;

    // Mix

    while(len >= 4)
    {
      d = *(uint32_t * )data;
      t = (t >> sr) | (d << sl);

      uint32_t k = t;

      MIX(h,k,m);

      t = d;

      data += 4;
      len -= 4;
    }

    // Handle leftover data in temp registers

    d = 0;

    if(len >= align)
    {
      switch(align)
      {
      case 3: d |= data[2] << 16;
      case 2: d |= data[1] << 8;
      case 1: d |= data[0];
      }

      uint32_t k = (t >> sr) | (d << sl);
      MIX(h,k,m);

      data += align;
      len -= align;

      //----------
      // Handle tail bytes

      switch(len)
      {
      case 3: h ^= data[2] << 16;
      case 2: h ^= data[1] << 8;
      case 1: h ^= data[0];
          h *= m;
      };
    }
    else
    {
      switch(len)
      {
      case 3: d |= data[2] << 16;
      case 2: d |= data[1] << 8;
      case 1: d |= data[0];
      case 0: h ^= (t >> sr) | (d << sl);
          h *= m;
      }
    }

    h ^= h >> 13;
    h *= m;
    h ^= h >> 15;

    return h;
  }
  else
  {
    while(len >= 4)
    {
      uint32_t k = *(uint32_t * )data;

      MIX(h,k,m);

      data += 4;
      len -= 4;
    }

    //----------
    // Handle tail bytes

    switch(len)
    {
    case 3: h ^= data[2] << 16;
    case 2: h ^= data[1] << 8;
    case 1: h ^= data[0];
        h *= m;
    };

    h ^= h >> 13;
    h *= m;
    h ^= h >> 15;

    return h;
  }
*)
end;

{ TMurMur3 }
// https://github.com/rurban/smhasher/blob/master/MurmurHash3.cpp
class procedure TMurMur3.Hash_x86_32(const Key; KeyLen: UInt32; const Seed: UInt32; OutVal: Pointer);
begin

end;

class procedure TMurMur3.Hash_x86_128(const Key; KeyLen: UInt32; const Seed: UInt32; OutVal: Pointer);
begin

end;

class procedure TMurMur3.Hash_x64_128(const Key; KeyLen: UInt32; const Seed: UInt32; OutVal: Pointer);
begin

end;

class function TMurMur3.Hash(const Key; KeyLen: UInt32; const Seed: UInt32): UInt64;
begin
{$IFDEF CPUX64}
	TMurMur3.Hash_x64_128(Key, KeyLen, Seed, @Result);
{$ELSE}
	TMurMur3.Hash_x86_128(Key, KeyLen, Seed, @Result);
{$ENDIF}
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
