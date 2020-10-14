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
  UInt32Array  = array[0..8191] of UInt32;
  PUInt32Array = ^UInt32Array;
  UInt64Array  = array[0..4095] of UInt64;
  PUInt64Array = ^UInt64Array;

  TMurMur1 = class
  public
    class function Hash(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
    class function HashAligned(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
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
    procedure MixTail(var data: PByteArray; var dataLen, idx: Integer);
  public
    class function Hash(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
    class function HashA(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
    class function Hash64A(const Key; KeyLen: UInt32; const Seed: UInt64): UInt64;
    class function Hash64B(const Key; KeyLen: UInt32; const Seed: UInt64): UInt64;
    class function HashNeutral(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
    class function HashAligned(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;

    constructor Create(Seed: UInt32);
    procedure Add(const value; dataLen: UInt32);
    function Calculate: UInt32;
  end;

  TMurMur3 = class
  public
    class procedure Hash_x86_32(const Key; KeyLen: UInt32; const Seed: UInt32; OutVal: Pointer);
    class procedure Hash_x86_128(const Key; KeyLen: UInt32; const Seed: UInt32; OutVal: Pointer);
    class procedure Hash_x64_128(const Key; KeyLen: UInt32; const Seed: UInt32; OutVal: Pointer);
    class function Hash(const Key; KeyLen: UInt32; const Seed: UInt32): UInt64;
  end;

implementation
uses
  Math;

{ Utils }
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
class function TMurMur1.Hash(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
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
class function TMurMur1.HashAligned(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
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
class function TMurMur2.Hash(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
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
class function TMurMur2.HashA(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
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
class function TMurMur2.Hash64A(const Key; KeyLen: UInt32; const Seed: UInt64): UInt64;
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
class function TMurMur2.Hash64B(const Key; KeyLen: UInt32; const Seed: UInt64): UInt64;
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
class function TMurMur2.HashNeutral(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
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
class function TMurMur2.HashAligned(const Key; KeyLen: UInt32; const Seed: UInt32): UInt32;
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
  fHash  = Seed;
  fTail  = 0;
  fCount = 0;
  fSize  = 0;
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

  MixTail(data, len);

  while len >= 4 do
  begin
    k = PUInt32(@(data[i]))^;

    mmix(fHash, k, m, r);

    Inc(i, 4);
    Dec(dataLen, 4);
  end;

  MixTail(data, len);
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

procedure TMurMur2.MixTail(const data: PByteArray; var dataLen, idx: Integer);
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
class procedure TMurMur3.Hash_x86_32(const Key; KeyLen: UInt32; const Seed: UInt32; OutVal: Pointer);
begin
(*
  const uint8_t * data = (const uint8_t* )key;
  const int nblocks = len / 4;

  uint32_t h1 = seed;

  const uint32_t c1 = 0xcc9e2d51;
  const uint32_t c2 = 0x1b873593;

  //----------
  // body

  const uint32_t * blocks = (const uint32_t * )(data + nblocks*4);

  for(int i = -nblocks; i; i++)
  {
    uint32_t k1 = getblock32(blocks,i);

    k1 *= c1;
    k1 = ROTL32(k1,15);
    k1 *= c2;

    h1 ^= k1;
    h1 = ROTL32(h1,13);
    h1 = h1*5+0xe6546b64;
  }

  //----------
  // tail

  const uint8_t * tail = (const uint8_t* )(data + nblocks*4);

  uint32_t k1 = 0;

  switch(len & 3)
  {
  case 3: k1 ^= tail[2] << 16;
  case 2: k1 ^= tail[1] << 8;
  case 1: k1 ^= tail[0];
          k1 *= c1; k1 = ROTL32(k1,15); k1 *= c2; h1 ^= k1;
  };

  //----------
  // finalization

  h1 ^= len;

  h1 = fmix32(h1);

  *(uint32_t* )out = h1;
*)
end;

//-----------------------------------------------------------------------------
// objsize: 0x160-0x4bb: 859
class procedure TMurMur3.Hash_x86_128(const Key; KeyLen: UInt32; const Seed: UInt32; OutVal: Pointer);
begin
(*
  const uint8_t * data = (const uint8_t* )key;
  const int nblocks = len / 16;

  uint32_t h1 = seed;
  uint32_t h2 = seed;
  uint32_t h3 = seed;
  uint32_t h4 = seed;

  const uint32_t c1 = 0x239b961b;
  const uint32_t c2 = 0xab0e9789;
  const uint32_t c3 = 0x38b34ae5;
  const uint32_t c4 = 0xa1e38b93;

  //----------
  // body

  const uint32_t * blocks = (const uint32_t * )(data + nblocks*16);

  for(int i = -nblocks; i; i++)
  {
    uint32_t k1 = getblock32(blocks,i*4+0);
    uint32_t k2 = getblock32(blocks,i*4+1);
    uint32_t k3 = getblock32(blocks,i*4+2);
    uint32_t k4 = getblock32(blocks,i*4+3);

    k1 *= c1; k1  = ROTL32(k1,15); k1 *= c2; h1 ^= k1;

    h1 = ROTL32(h1,19); h1 += h2; h1 = h1*5+0x561ccd1b;

    k2 *= c2; k2  = ROTL32(k2,16); k2 *= c3; h2 ^= k2;

    h2 = ROTL32(h2,17); h2 += h3; h2 = h2*5+0x0bcaa747;

    k3 *= c3; k3  = ROTL32(k3,17); k3 *= c4; h3 ^= k3;

    h3 = ROTL32(h3,15); h3 += h4; h3 = h3*5+0x96cd1c35;

    k4 *= c4; k4  = ROTL32(k4,18); k4 *= c1; h4 ^= k4;

    h4 = ROTL32(h4,13); h4 += h1; h4 = h4*5+0x32ac3b17;
  }

  //----------
  // tail

  const uint8_t * tail = (const uint8_t* )(data + nblocks*16);

  uint32_t k1 = 0;
  uint32_t k2 = 0;
  uint32_t k3 = 0;
  uint32_t k4 = 0;

  switch(len & 15)
  {
  case 15: k4 ^= tail[14] << 16;
  case 14: k4 ^= tail[13] << 8;
  case 13: k4 ^= tail[12] << 0;
           k4 *= c4; k4  = ROTL32(k4,18); k4 *= c1; h4 ^= k4;

  case 12: k3 ^= tail[11] << 24;
  case 11: k3 ^= tail[10] << 16;
  case 10: k3 ^= tail[ 9] << 8;
  case  9: k3 ^= tail[ 8] << 0;
           k3 *= c3; k3  = ROTL32(k3,17); k3 *= c4; h3 ^= k3;

  case  8: k2 ^= tail[ 7] << 24;
  case  7: k2 ^= tail[ 6] << 16;
  case  6: k2 ^= tail[ 5] << 8;
  case  5: k2 ^= tail[ 4] << 0;
           k2 *= c2; k2  = ROTL32(k2,16); k2 *= c3; h2 ^= k2;

  case  4: k1 ^= tail[ 3] << 24;
  case  3: k1 ^= tail[ 2] << 16;
  case  2: k1 ^= tail[ 1] << 8;
  case  1: k1 ^= tail[ 0] << 0;
           k1 *= c1; k1  = ROTL32(k1,15); k1 *= c2; h1 ^= k1;
  };

  //----------
  // finalization

  h1 ^= len; h2 ^= len; h3 ^= len; h4 ^= len;

  h1 += h2; h1 += h3; h1 += h4;
  h2 += h1; h3 += h1; h4 += h1;

  h1 = fmix32(h1);
  h2 = fmix32(h2);
  h3 = fmix32(h3);
  h4 = fmix32(h4);

  h1 += h2; h1 += h3; h1 += h4;
  h2 += h1; h3 += h1; h4 += h1;

  ((uint32_t* )out)[0] = h1;
  ((uint32_t* )out)[1] = h2;
  ((uint32_t* )out)[2] = h3;
  ((uint32_t* )out)[3] = h4;
*)
end;

//-----------------------------------------------------------------------------
// objsize: 0x500-0x7bb: 699
class procedure TMurMur3.Hash_x64_128(const Key; KeyLen: UInt32; const Seed: UInt32; OutVal: Pointer);
begin
(*
  const uint8_t * data = (const uint8_t* )key;
  const int nblocks = len / 16;

  uint64_t h1 = seed;
  uint64_t h2 = seed;

  const uint64_t c1 = BIG_CONSTANT(0x87c37b91114253d5);
  const uint64_t c2 = BIG_CONSTANT(0x4cf5ad432745937f);

  //----------
  // body

  const uint64_t * blocks = (const uint64_t * )(data);

  for(int i = 0; i < nblocks; i++)
  {
    uint64_t k1 = getblock64(blocks,i*2+0);
    uint64_t k2 = getblock64(blocks,i*2+1);

    k1 *= c1; k1  = ROTL64(k1,31); k1 *= c2; h1 ^= k1;

    h1 = ROTL64(h1,27); h1 += h2; h1 = h1*5+0x52dce729;

    k2 *= c2; k2  = ROTL64(k2,33); k2 *= c1; h2 ^= k2;

    h2 = ROTL64(h2,31); h2 += h1; h2 = h2*5+0x38495ab5;
  }

  //----------
  // tail

  const uint8_t * tail = (const uint8_t* )(data + nblocks*16);

  uint64_t k1 = 0;
  uint64_t k2 = 0;

  switch(len & 15)
  {
  case 15: k2 ^= ((uint64_t)tail[14]) << 48;
  case 14: k2 ^= ((uint64_t)tail[13]) << 40;
  case 13: k2 ^= ((uint64_t)tail[12]) << 32;
  case 12: k2 ^= ((uint64_t)tail[11]) << 24;
  case 11: k2 ^= ((uint64_t)tail[10]) << 16;
  case 10: k2 ^= ((uint64_t)tail[ 9]) << 8;
  case  9: k2 ^= ((uint64_t)tail[ 8]) << 0;
           k2 *= c2; k2  = ROTL64(k2,33); k2 *= c1; h2 ^= k2;

  case  8: k1 ^= ((uint64_t)tail[ 7]) << 56;
  case  7: k1 ^= ((uint64_t)tail[ 6]) << 48;
  case  6: k1 ^= ((uint64_t)tail[ 5]) << 40;
  case  5: k1 ^= ((uint64_t)tail[ 4]) << 32;
  case  4: k1 ^= ((uint64_t)tail[ 3]) << 24;
  case  3: k1 ^= ((uint64_t)tail[ 2]) << 16;
  case  2: k1 ^= ((uint64_t)tail[ 1]) << 8;
  case  1: k1 ^= ((uint64_t)tail[ 0]) << 0;
           k1 *= c1; k1  = ROTL64(k1,31); k1 *= c2; h1 ^= k1;
  };

  //----------
  // finalization
  h1 ^= len; h2 ^= len;

  h1 += h2;
  h2 += h1;

  h1 = fmix64(h1);
  h2 = fmix64(h2);

  h1 += h2;
  h2 += h1;

  ((uint64_t* )out)[0] = h1;
  ((uint64_t* )out)[1] = h2;
*)
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
