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
uses
  SysUtils;

type
  TMurMur1 = class
  public
    class function Hash(const Key; const KeyLen, Seed: UInt32): UInt32;
    class function HashAligned(const Key; const KeyLen, Seed: UInt32): UInt32;
  end;

  {
    Includes a sample implementation of MurmurHash2A designed to work incrementally.

    Usage:
      var
        hasher: TMurMur2;
        hash:   UInt32;
      begin
        hasher := hasher.Create(seed);
        hasher.Add(data1, size1);
        hasher.Add(data2, size2);
        // ...
        hasher.Add(dataN, sizeN);
        hash := hasher.Hash;
      end;
  }
  TMurMur2 = class(TObject)
  strict private
    fHash,
    fTail,
    fCount,
    fSize:  UInt32;
    const
      m: UInt32 = $5bd1e995;
      r: UInt32 = 24;
    procedure MixTail(const data: PByteArray; var dataLen: UInt32; var idx: Integer);
  public
    class function Hash(const Key; const KeyLen, Seed: UInt32): UInt32;
    class function HashA(const Key; const KeyLen, Seed: UInt32): UInt32;
    class function Hash64A(const Key; const KeyLen: UInt32; const Seed: UInt64): UInt64;
    class function Hash64B(const Key; const KeyLen: UInt32; const Seed: UInt64): UInt64;
    class function HashNeutral(const Key; const KeyLen, Seed: UInt32): UInt32;
    class function HashAligned(const Key; const KeyLen, Seed: UInt32): UInt32;

    constructor Create(Seed: UInt32);
    procedure Add(const value; dataLen: UInt32);
    function Calculate: UInt32;
  end;

  TMurMur3 = class
  public
    class function Hash_x86_32(const Key; const KeyLen, Seed: UInt32): UInt32;
    class function Hash_x86_128(const Key; const KeyLen, Seed: UInt32): string;
    class function Hash_x64_128(const Key; const KeyLen, Seed: UInt32): string;
    class function Hash(const Key; const KeyLen, Seed: UInt32): string;
  end;

implementation
uses
  Math;

{ Utils }
type
  UInt32Array  = array[0..8191] of UInt32;
  PUInt32Array = ^UInt32Array;
  UInt64Array  = array[0..4095] of UInt64;
  PUInt64Array = ^UInt64Array;

const
  SH_AMNT_4  = 4;
  SH_AMNT_8  = 8;
  SH_AMNT_10 = 10;
  SH_AMNT_13 = 13;
  SH_AMNT_15 = 15;
  SH_AMNT_16 = 16;
  SH_AMNT_17 = 17;
  SH_AMNT_24 = 24;
  SH_AMNT_32 = 32;
  SH_AMNT_47 = 47;
  SH_AMNT_64 = 64;

function ROTL32(x: UInt32; n: Int8): UInt32; inline;
begin
  Result := (x shl n) or (x shr (SH_AMNT_32 - n));
end;

function ROTL64(x: UInt64; n: Int8): UInt64; inline;
begin
  Result := (x shl n) or (x shr (SH_AMNT_64 - n));
end;

{------------------------------------------------------------------------------
  Finalization mix - force all bits of a hash block to avalanche
}

function fmix32(h: UInt32): UInt32; inline;
begin
  h := h xor (h shr SH_AMNT_16);
  h := h * $85ebca6b;
  h := h xor (h shr SH_AMNT_13);
  h := h * $c2b2ae35;
  h := h xor (h shr SH_AMNT_16);

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
class function TMurMur1.Hash(const Key; const KeyLen, Seed: UInt32): UInt32;
const
  m: UInt32 = $c6a4a793;
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
    Result := Result xor (Result shr SH_AMNT_16);

    Inc(i, 4);
    Dec(len, 4);
  end;

  case len of
    3:
      Result := Result + (data[i + 2] shl SH_AMNT_16);
    2:
      Result := Result + (data[i + 1] shl SH_AMNT_8);
    1:
    begin
      Result := Result + data[i];
      Result := Result * m;
      Result := Result xor (Result shr SH_AMNT_16);
    end;
  end;

  Result := Result * m;
  Result := Result xor (Result shr SH_AMNT_10);
  Result := Result * m;
  Result := Result xor (Result shr SH_AMNT_17);
end;

{------------------------------------------------------------------------------
  TMurmur1.HashAligned, by Austin Appleby

  Same algorithm as TMurmur1.Hash, but only does aligned reads - should be
  safer on certain platforms.

  Performance should be equal to or better than the simple version.
  objsize: 0x160-0x4e3: 899
}
class function TMurMur1.HashAligned(const Key; const KeyLen, Seed: UInt32): UInt32;
const
  m: UInt32 = $c6a4a793;
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
      1: t := t or (data[2] shl SH_AMNT_16);
      2: t := t or (data[1] shl SH_AMNT_8);
      3: t := t or data[0];
    end;

    t := t shl (SH_AMNT_8 * align);
    Inc(i, 4 - align);
    Dec(len, 4 - align);

    sl := SH_AMNT_8 * (4 - align);
    sr := SH_AMNT_8 * align;

    // Mix
    while len >= 4 do
    begin
      d      := PUInt32(@(data[i]))^;
      t      := (t shr sr) or (d shl sl);
      Result := Result + t;
      Result := Result * m;
      Result := Result xor (Result shr SH_AMNT_16);
      t      := d;

      Inc(i, 4);
      Dec(len, 4);
    end;

    pack := Min(len, align);

    d := 0;

    case pack of
      3:
        d := d or (data[i + 2] shl SH_AMNT_16);
      2:
        d := d or (data[i + 1] shl SH_AMNT_8);
      1:
        d := d or data[i];
      0:
      begin
        Result := Result + ((SH_AMNT_16 shr sr) or (d shl sl));
        Result := Result * m;
        Result := Result xor (Result shr SH_AMNT_16);
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
      Result := Result xor (Result shr SH_AMNT_16);

      Inc(i, 4);
      Dec(len, 4);
    end;
  end;

  // Handle tail bytes
  case len of
    3:
      Result := Result + (data[i + 2] shl SH_AMNT_16);
    2:
      Result := Result + (data[i + 1] shl SH_AMNT_8);
    1:
    begin
      Result := Result + data[i];
      Result := Result * m;
      Result := Result xor (Result shr SH_AMNT_16);
    end;
  end;

  Result := Result * m;
  Result := Result xor (Result shr SH_AMNT_10);
  Result := Result * m;
  Result := Result xor (Result shr SH_AMNT_17);
end;

{ TMurMur2 }
// https://github.com/rurban/smhasher/blob/master/MurmurHash2.cpp
// objsize: 0-0x166: 358
class function TMurMur2.Hash(const Key; const KeyLen, Seed: UInt32): UInt32;
// 'm' and 'r' are mixing constants generated offline. They're not really 'magic', they just happen to work well.
const
  m: UInt32 = $5bd1e995;
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

    mmix(Result, k, m, SH_AMNT_24);

    Inc(i, 4);
    Dec(len, 4);
  end;

  // Handle the last few bytes of the input array
  case len of
    3:
      Result := Result xor data[i + 2] shl SH_AMNT_16;
    2:
      Result := Result xor data[i + 1] shl SH_AMNT_8;
    1:
    begin
      Result := Result xor data[i];
      Result := Result * m;
    end;
  end;

  // Do a few final mixes of the hash to ensure the last few bytes are well-incorporated.
  Result := Result xor (Result shr SH_AMNT_13);
  Result := Result * m;
  Result := Result xor (Result shr SH_AMNT_15);
end;

{------------------------------------------------------------------------------
  TMurMur2.HashA, by Austin Appleby

  This is a variant of TMurMur2.Hash modified to use the Merkle-Damgard
  construction. Bulk speed should be identical to TMurMur2.Hash, small-key speed
  will be 10%-20% slower due to the added overhead at the end of the hash.

  This variant fixes a minor issue where null keys were more likely to
  collide with each other than expected, and also makes the function
  more amenable to incremental implementations.

  objsize: 0x500-0x697: 407
}
class function TMurMur2.HashA(const Key; const KeyLen, Seed: UInt32): UInt32;
const
  m: UInt32 = $5bd1e995;
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

    mmix(Result, k, m, SH_AMNT_24);

    Inc(i, 4);
    Dec(len, 4);
  end;

  t := 0;

  case len of
    3:
      t := t xor (data[i + 2] shl SH_AMNT_16);
    2:
      t := t xor (data[i + 1] shl SH_AMNT_8);
    1:
      t := t xor data[i];
  end;

  mmix(Result, t, m, SH_AMNT_24);
  mmix(Result, l, m, SH_AMNT_24);

  Result := Result xor (Result shr SH_AMNT_13);
  Result := Result * m;
  Result := Result xor (Result shr SH_AMNT_15);
end;

{------------------------------------------------------------------------------
  TMurMur2.Hash64A, 64-bit versions, by Austin Appleby

  The same caveats as 32-bit TMurMur2.Hash apply here - beware of alignment
  and endian-ness issues if used across multiple platforms.

  64-bit hash for 64-bit platforms
  objsize: 0x170-0x321: 433
}
class function TMurMur2.Hash64A(const Key; const KeyLen: UInt32; const Seed: UInt64): UInt64;
const
  m: UInt64 = $c6a4a7935bd1e995;
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
    k := k xor (k shr SH_AMNT_47);
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
      Result := Result xor (UInt64(data[i + 4]) shl SH_AMNT_32);
    4:
      Result := Result xor (UInt64(data[i + 3]) shl SH_AMNT_24);
    3:
      Result := Result xor (UInt64(data[i + 2]) shl SH_AMNT_16);
    2:
      Result := Result xor (UInt64(data[i + 1]) shl SH_AMNT_8);
    1:
    begin
      Result := Result xor UInt64(data[i]);
      Result := Result * m;
    end;
  end;

  Result := Result xor (Result shr SH_AMNT_47);
  Result := Result * m;
  Result := Result xor (Result shr SH_AMNT_47);
end;

// 64-bit hash for 32-bit platforms
// objsize: 0x340-0x4fc: 444
class function TMurMur2.Hash64B(const Key; const KeyLen: UInt32; const Seed: UInt64): UInt64;
const
  m: UInt32 = $5bd1e995;
var
  h1, h2, k1, k2: UInt32;
  data:           PByteArray;
  i, len:         Integer;
begin
  h1   := UInt32(Seed) xor KeyLen;
  h2   := UInt32(Seed shr SH_AMNT_32);
  data := PByteArray(@Key);
  len  := KeyLen;
  i    := 0;

  while len >= 8 do
  begin
    k1 := PUInt32(@(data[i]))^;
    k1 := k1 * m;
    k1 := k1 * (k1 shr SH_AMNT_24);
    k1 := k1 * m;
    h1 := h1 * m;
    h1 := h1 xor k1;
    Inc(i, 4);
    Dec(len, 4);

    k2 := PUInt32(@(data[i]))^;
    k2 := k2 * m;
    k2 := k2 xor (k2 shr SH_AMNT_24);
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
    k1 := k1 xor (k1 shr SH_AMNT_24);
    k1 := k1 * m;
    h1 := h1 * m;
    h1 := h1 xor k1;
    Inc(i, 4);
    Dec(len, 4);
  end;

  case len of
    3:
      h2 := h2 xor (data[i + 2] shl SH_AMNT_16);
    2:
      h2 := h2 xor (data[i + 1] shl SH_AMNT_8);
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
  h1 := h1 xor (h2 shr SH_AMNT_17);
  h1 := h1 * m;
  h2 := h2 xor (h1 shr 19);
  h2 := h2 * m;

  Result := h1;
  Result := (Result shl SH_AMNT_32) or h2;
end;

{------------------------------------------------------------------------------
  TMurMur2.HashNeutral, by Austin Appleby

  Same as TMurMur2.Hash, but endian- and alignment-neutral.
  Half the speed though, alas.
}
class function TMurMur2.HashNeutral(const Key; const KeyLen, Seed: UInt32): UInt32;
const
  m: UInt32 = $5bd1e995;
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
    k := k or (data[i + 1] shl SH_AMNT_8);
    k := k or (data[i + 2] shl SH_AMNT_16);
    k := k or (data[i + 3] shl SH_AMNT_24);

    k := k * m;
    k := k xor (k shr SH_AMNT_24);
    k := k * m;

    Result := Result * m;
    Result := Result xor k;

    Inc(i, 4);
    Dec(len, 4);
  end;

  case len of
    3:
      Result := Result xor data[i + 2] shl SH_AMNT_16;
    2:
      Result := Result xor data[i + 1] shl SH_AMNT_8;
    1:
    begin
      Result := Result xor data[i];
      Result := Result * m;
    end;
  end;

  Result := Result xor (Result shr SH_AMNT_13);
  Result := Result * m;
  Result := Result xor (Result shr SH_AMNT_15);
end;

{------------------------------------------------------------------------------
  TMurMur2.HashAligned, by Austin Appleby

  Same algorithm as TMurMur2.Hash, but only does aligned reads - should be safer
  on certain platforms.

  Performance will be lower than TMurMur2.Hash
}
class function TMurMur2.HashAligned(const Key; const KeyLen, Seed: UInt32): UInt32;
  procedure MIX(var h, k: UInt32; m: UInt32); inline;
  begin
    k := k * m;
    k := k xor (k shr SH_AMNT_24);
    k := k * m;
    h := h * m;
    h := h xor k;
  end;
const
  m: UInt32 = $5bd1e995;
var
  k, t, d:               UInt32;
  data:                  PByteArray;
  i, len, align, sl, sr: Integer;
begin
  Result := Seed xor KeyLen;
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
      1:
        t := t or (data[2] shl SH_AMNT_16);
      2:
        t := t or (data[1] shl SH_AMNT_8);
      3:
        t := t or data[0];
    end;

    t := t shl (SH_AMNT_8 * align);

    Inc(i, 4 - align);
    Dec(len, 4 - align);

    sl := SH_AMNT_8 * (4 - align);
    sr := SH_AMNT_8 * align;

    // Mix
    while len >= 4 do
    begin
      d := PUInt32(@(data[i]))^;
      t := (t shr sr) or (d shl sl);

      k := t;

      MIX(Result, k, m);

      t := d;

      Inc(i, 4);
      Dec(len, 4);
    end;

    // Handle leftover data in temp registers
    d := 0;

    if(len >= align) then
    begin
      case align of
        3:
          d := d or (data[i + 2] shl SH_AMNT_16);
        2:
          d := d or (data[i + 1] shl SH_AMNT_8);
        1:
          d := d or data[i];
      end;

      k := (t shr sr) or (d shl sl);
      MIX(Result, k, m);

      Inc(i, align);
      Dec(len, align);

      //----------
      // Handle tail bytes
      case len of
        3:
          Result := Result xor (data[i + 2] shl SH_AMNT_16);
        2:
          Result := Result xor (data[i + 1] shl SH_AMNT_8);
        1:
        begin
          Result := Result xor data[i];
          Result := Result * m;
        end;
      end;
    end else
    begin
      case len of
        3:
          d := d or (data[i + 2] shl SH_AMNT_16);
        2:
          d := d or (data[i + 1] shl SH_AMNT_8);
        1:
          d := d or data[i];
        0:
        begin
          Result := Result xor (t shr sr) or (d shl sl);
          Result := Result * m;
        end;
      end;
    end;

    Result := Result xor (Result shr SH_AMNT_13);
    Result := Result * m;
    Result := Result xor (Result shr SH_AMNT_15);
  end else
  begin
    while len >= 4 do
    begin
      k := PUInt32(@(data[i]))^;

      MIX(Result, k, m);

      Inc(i, 4);
      Dec(len, 4);
    end;

    //----------
    // Handle tail bytes
    case len of
      3:
        Result := Result xor (data[i + 2] shl SH_AMNT_16);
      2:
        Result := Result xor (data[i + 1] shl SH_AMNT_8);
      1:
      begin
        Result := Result xor data[i];
        Result := Result * m;
      end;
    end;

    Result := Result xor (Result shr SH_AMNT_13);
    Result := Result * m;
    Result := Result xor (Result shr SH_AMNT_15);
  end;
end;

constructor TMurMur2.Create(Seed: UInt32);
begin
  fHash  := Seed;
  fTail  := 0;
  fCount := 0;
  fSize  := 0;
end;

procedure TMurMur2.Add(const value; dataLen: UInt32);
var
  data:   PByteArray;
  len, k: UInt32;
  i:      Integer;
begin
  fSize := fSize + dataLen;
  len   := dataLen;
  data  := PByteArray(@value);

  MixTail(data, len, i);

  while len >= 4 do
  begin
    k := PUInt32(@(data[i]))^;

    mmix(fHash, k, m, r);

    Inc(i, 4);
    Dec(dataLen, 4);
  end;

  MixTail(data, len, i);
end;

function TMurMur2.Calculate: UInt32;
begin
  mmix(fHash, fTail, m, r);
  mmix(fHash, fSize, m, r);

  fHash := fHash xor (fHash shr 13);
  fHash := fHash * m;
  fHash := fHash xor (fHash shr 15);

  Result := fHash;
end;

procedure TMurMur2.MixTail(const data: PByteArray; var dataLen: UInt32; var idx: Integer);
begin
  while (dataLen > 0) and ((dataLen < 4) or (fCount > 0)) do
  begin
    fTail := fTail or (PByte(@(data[idx]))^ shl (fCount * SH_AMNT_8));
    Inc(idx);
    Inc(fCount);
    Dec(dataLen);

    if fCount = 4 then
    begin
        mmix(fHash, fTail, m, r);
        fTail  := 0;
        fCount := 0;
    end;
  end;
end;

{ TMurMur3 }
// https://github.com/rurban/smhasher/blob/master/MurmurHash3.cpp
//-----------------------------------------------------------------------------
// objsize: 0x0-0x15f: 351
class function TMurMur3.Hash_x86_32(const Key; const KeyLen, Seed: UInt32): UInt32;
const
  c1: UInt32 = $cc9e2d51;
  c2: UInt32 = $1b873593;
var
  data:       PByteArray;
  blocks:     PUInt32Array;
  i, nBlocks: Integer;
  len, k1:    UInt32;
begin
  len     := KeyLen;
  data    := PByteArray(@Key);
  nblocks := Math.Floor(len / 4);
  Result  := Seed;

  //----------
  // body
  blocks := PUInt32Array(data);

  for i := 0 to nblocks - 1 do
  begin
    k1 := getblock32(blocks, i);

    k1 := k1 * c1;
    k1 := ROTL32(k1, SH_AMNT_15);
    k1 := k1 * c2;

    Result := Result xor k1;
    Result := ROTL32(Result, SH_AMNT_13);
    Result := Result * 5 + $e6546b64;
  end;

  //----------
  // tail
  i  := nblocks * 4;
  k1 := 0;

  case len and 3 of
    3:
      k1 := k1 xor (data[i + 2] shl SH_AMNT_16);
    2:
      k1 := k1 xor (data[i + 1] shl SH_AMNT_8);
    1:
    begin
      k1     := k1 xor data[i];
      k1     := k1 * c1;
      k1     := ROTL32(k1, SH_AMNT_15);
      k1     := k1 * c2;
      Result := Result xor k1;
    end;
  end;

  //----------
  // finalization
  Result := Result xor len;
  Result := fmix32(Result);
end;

//-----------------------------------------------------------------------------
// objsize: 0x160-0x4bb: 859
class function TMurMur3.Hash_x86_128(const Key; const KeyLen, Seed: UInt32): string;
const
  c1: UInt32 = $239b961b;
  c2: UInt32 = $ab0e9789;
  c3: UInt32 = $38b34ae5;
  c4: UInt32 = $a1e38b93;
var
  data:           PByteArray;
  blocks:         PUInt32Array;
  i, nBlocks:     Integer;
  len,
  h1, h2, h3, h4,
  k1, k2, k3, k4: UInt32;
begin
  len     := KeyLen;
  data    := PByteArray(@Key);
  nblocks := Math.Floor(len / 16);
  h1      := Seed;
  h2      := Seed;
  h3      := Seed;
  h4      := Seed;

  //----------
  // body
  blocks := PUInt32Array(data);

  for i := 0 to nblocks - 1 do
  begin
    k1 := getblock32(blocks, i * 4);
    k2 := getblock32(blocks, i * 4 + 1);
    k3 := getblock32(blocks, i * 4 + 2);
    k4 := getblock32(blocks, i * 4 + 3);

    k1 := k1 * c1;
    k1 := ROTL32(k1, SH_AMNT_15);
    k1 := k1 * c2;
    h1 := h1 xor k1;

    h1 := ROTL32(h1, 19);
    h1 := h1 + h2;
    h1 := h1 * 5 + $561ccd1b;

    k2 := k2 * c2;
    k2 := ROTL32(k2, SH_AMNT_16);
    k2 := k2 * c3;
    h2 := h2 xor k2;

    h2 := ROTL32(h2, SH_AMNT_17);
    h2 := h2 + h3;
    h2 := h2 * 5 + $0bcaa747;

    k3 := k3 * c3;
    k3 := ROTL32(k3, SH_AMNT_17);
    k3 := k3 * c4;
    h3 := h3 xor k3;

    h3 := ROTL32(h3, SH_AMNT_15);
    h3 := h3 + h4;
    h3 := h3 * 5 + $96cd1c35;

    k4 := k4 * c4;
    k4 := ROTL32(k4, 18);
    k4 := k4 * c1;
    h4 := h4 xor k4;

    h4 := ROTL32(h4, SH_AMNT_13);
    h4 := h4 + h1;
    h4 := h4 * 5 + $32ac3b17;
  end;

  //----------
  // tail
  i  := nblocks * 16;
  k1 := 0;
  k2 := 0;
  k3 := 0;
  k4 := 0;

  case len and 15 of
    15:
      k4 := k4 xor (data[i + 14] shl SH_AMNT_16);
    14:
      k4 := k4 xor (data[i + 13] shl SH_AMNT_8);
    13:
    begin
      k4 := k4 xor (data[i + 12] shl 0);
      k4 := k4 * c4;
      k4 := ROTL32(k4, 18);
      k4 := k4 * c1;
      h4 := h4 xor k4;
    end;
    12:
      k3 := k3 xor (data[i + 11] shl SH_AMNT_24);
    11:
      k3 := k3 xor (data[i + 10] shl SH_AMNT_16);
    10:
      k3 := k3 xor (data[i + 9] shl SH_AMNT_8);
    9:
    begin
      k3 := k3 xor (data[i + 8] shl 0);
      k3 := k3 * c3;
      k3 := ROTL32(k3, SH_AMNT_17);
      k3 := k3 * c4;
      h3 := h3 xor k3;
    end;
    8:
      k2 := k2 xor (data[i + 7] shl SH_AMNT_24);
    7:
      k2 := k2 xor (data[i + 6] shl SH_AMNT_16);
    6:
      k2 := k2 xor (data[i + 5] shl SH_AMNT_8);
    5:
    begin
      k2 := k2 xor (data[i + 4] shl 0);
      k2 := k2 * c2;
      k2 := ROTL32(k2, SH_AMNT_16);
      k2 := k2 * c3;
      h2 := h2 xor k2;
    end;
    4:
      k1 := k1 xor (data[i + 3] shl SH_AMNT_24);
    3:
      k1 := k1 xor (data[i + 2] shl SH_AMNT_16);
    2:
      k1 := k1 xor (data[i + 1] shl SH_AMNT_8);
    1:
    begin
      k1 := k1 xor (data[i] shl 0);
      k1 := k1 * c1;
      k1 := ROTL32(k1, SH_AMNT_15);
      k1 := k1 * c2;
      h1 := h1 xor k1;
    end;
  end;

  //----------
  // finalization
  h1 := h1 xor len;
  h2 := h2 xor len;
  h3 := h3 xor len;
  h4 := h4 xor len;

  h1 := h1 + h2;
  h1 := h1 + h3;
  h1 := h1 + h4;
  h2 := h2 + h1;
  h3 := h3 + h1;
  h4 := h4 + h1;

  h1 := fmix32(h1);
  h2 := fmix32(h2);
  h3 := fmix32(h3);
  h4 := fmix32(h4);

  h1     := h1 + h2;
  h1     := h1 + h3;
  Result := IntToHex(h1 + h4) + IntToHex(h2 + h1) + IntToHex(h3 + h1) + IntToHex(h4 + h1);
end;

//-----------------------------------------------------------------------------
// objsize: 0x500-0x7bb: 699
class function TMurMur3.Hash_x64_128(const Key; const KeyLen, Seed: UInt32): string;
const
  c1: UInt64 = $87c37b91114253d5;
  c2: UInt64 = $4cf5ad432745937f;
var
  data:           PByteArray;
  blocks:         PUInt64Array;
  i, nBlocks:     Integer;
  len,
  h1, h2, k1, k2: UInt64;
begin
  len     := KeyLen;
  data    := PByteArray(@Key);
  nblocks := Math.Floor(len / 16);
  h1      := Seed;
  h2      := Seed;

  //----------
  // body
  blocks := PUInt64Array(data);

  for i := 0 to nblocks - 1 do
  begin
    k1 := getblock64(blocks, i * 2);
    k2 := getblock64(blocks, i * 2 + 1);

    k1 := k1 * c1;
    k1 := ROTL64(k1, 31);
    k1 := k1 * c2;
    h1 := h1 xor k1;

    h1 := ROTL64(h1, 27);
    h1 := h1 + h2;
    h1 := h1 * 5 + $52dce729;

    k2 := k2 * c2;
    k2 := ROTL64(k2, 33);
    k2 := k2 * c1;
    h2 := h2 xor k2;

    h2 := ROTL64(h2, 31);
    h2 := h2 + h1;
    h2 := h2 * 5 + $38495ab5;
  end;

  //----------
  // tail
  i  := nblocks * 16;
  k1 := 0;
  k2 := 0;

  case len and 15 of
    15:
      k2 := k2 xor (UInt64(data[i + 14]) shl 48);
    14:
      k2 := k2 xor (UInt64(data[i + 13]) shl 40);
    13:
      k2 := k2 xor (UInt64(data[i + 12]) shl 32);
    12:
      k2 := k2 xor (UInt64(data[i + 11]) shl 24);
    11:
      k2 := k2 xor (UInt64(data[i + 10]) shl 16);
    10:
      k2 := k2 xor (UInt64(data[i + 9]) shl 8);
    9:
    begin
      k2 := k2 xor (UInt64(data[i + 8]) shl 0);
      k2 := k2 * c2;
      k2 := ROTL64(k2, 33);
      k2 := k2 * c1;
      h2 := h2 xor k2;
    end;
    8:
      k1 := k1 xor (UInt64(data[i + 7]) shl 56);
    7:
      k1 := k1 xor (UInt64(data[i + 6]) shl 48);
    6:
      k1 := k1 xor (UInt64(data[i + 5]) shl 40);
    5:
      k1 := k1 xor (UInt64(data[i + 4]) shl 32);
    4:
      k1 := k1 xor (UInt64(data[i + 3]) shl 24);
    3:
      k1 := k1 xor (UInt64(data[i + 2]) shl 16);
    2:
      k1 := k1 xor (UInt64(data[i + 1]) shl 8);
    1:
    begin
      k1 := k1 xor (UInt64(data[i + 0]) shl 0);
      k1 := k1 * c1;
      k1 := ROTL64(k1, 31);
      k1 := k1 * c2;
      h1 := h1 xor k1;
    end;
  end;

  //----------
  // finalization
  h1 := h1 xor len;
  h2 := h2 xor len;

  h1 := h1 + h2;
  h2 := h2 + h1;

  h1 := fmix64(h1);
  h2 := fmix64(h2);

  Result := IntToHex(h1 + h2) + IntToHex(h2 + h1);
end;

class function TMurMur3.Hash(const Key; const KeyLen, Seed: UInt32): string;
begin
{$IFDEF CPUX64}
  Result := TMurMur3.Hash_x64_128(Key, KeyLen, Seed);
{$ELSE}
  Result := TMurMur3.Hash_x86_128(Key, KeyLen, Seed);
{$ENDIF}
end;

end.
