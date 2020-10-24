unit MurMurHash3Tests;
interface
uses
  DUnitX.TestFramework, SysUtils, MurMurHash;

type
  [TestFixture]
  TMurMur3Tests = class(TObject)
  protected
    fFreq: Int64;
  public
    [Setup]
    procedure SetUp;
    [TestCase('Canonical MurMur3 Hash', '')]
    procedure SelfTest_Canonical_MurMur_Three_Hash;
    [TestCase('MurMur3 32-bit Test Vectors', '')]
    procedure SelfTest_MurMur_Three_32_TestVectors;
    [TestCase('MurMur3 128-bit hash 32-bit Test Vectors', '')]
    procedure SelfTest_MurMur_Three_128_x86_TestVectors;
    [TestCase('MurMur3 128-bit hash 64-bit Test Vectors', '')]
    procedure SelfTest_MurMur_Three_128_x64_TestVectors;
  end;

implementation
uses
  Types, Windows, System.Hash;

function HexStringToBytes(s: string): TBytes;
var
  i, j, n: Integer;
begin
  for i := Length(s) downto 1 do
    if s[i] = ' ' then
      Delete(s, i, 1);

  SetLength(Result, Length(s) div 2);

  i := 1;
  j := 0;

  while (i < Length(s)) do
  begin
    n         := StrToInt('0x' + s[i] + s[i + 1]);
    Result[j] := n;
    Inc(i, 2);
    Inc(j, 1);
  end;
end;

{ TMurMur3Tests }

(*
  The canonical Murmur1 tests are to perform multiple hashes, then hash the result of the hashes.

  Expected Result: 0xB0F57EE3
    main.cpp
    https://github.com/rurban/smhasher/blob/9c9619c3beef4241e8e96305fbbee3ec069d3081/main.cpp

  Hash keys of the form {0}, {0,1}, {0,1,2}... up to N=255,
  using 256-N as the seed

  Key                Seed         Hash
  ==================  ===========  ==========
  00                  0x00000100   0x........
  00 01               0x000000FF   0x........
  00 01 02            0x000000FE   0x........
  00 01 02 03         0x000000FD   0x........
  ...
  00 01 02 ... FE     0x00000002   0x........
  00 01 02 ... FE FF  0x00000001   0x........

  And then hash the concatenation of the 255 computed hashes
*)
procedure TMurMur3Tests.SelfTest_Canonical_MurMur_Three_Hash;
const
  Expected = '2267EE00B57E7ACC3B64E15E2267EE00';
var
  key:    array[0..255] of Byte;   //256 hashes
  hashes: TStringBuilder; //result of each of the 256 hashes
  i:      Integer;
  actual: string;
  t1, t2: Int64;
begin
  Log('Using TMurmur3.Hash > Hashing 256 values, followed by hashing the result set of the hashes');
  hashes := TStringBuilder.Create;

  if not QueryPerformanceCounter({out}t1) then
    t1 := 0;

  for i := 0 to 255 do
  begin
    key[i] := Byte(i);
    hashes.Append(TMurmur3.Hash(key[0], i, 256 - i));
  end;

  actual := hashes.ToString;
  actual := TMurmur3.Hash(Pointer(actual)^, Length(actual) * SizeOf(Char), 0);
  hashes.Free;

  if not QueryPerformanceCounter({out}t2) then
    t2 := 0;

  WriteLn('Expected = ' + Expected + ' ; Actual = ' + actual);
  Status('Test completed in ' + FloatToStrF((t2 - t1) / fFreq * 1000000, ffFixed, 15, 3) + ' µs' + sLineBreak + sLineBreak);
  Assert.AreEqual(Expected, actual); // testcode
end;

procedure TMurMur3Tests.SelfTest_MurMur_Three_32_TestVectors;
var
  ws:     string;
  t1, t2: Int64;

  procedure t(const KeyHexString: string; Seed, Expected: Cardinal);
  var
    actual: UInt32;
    key:    TByteDynArray;
  begin
    key := HexStringToBytes(KeyHexString);

    if not QueryPerformanceCounter(t1) then t1 := 0;

    actual := TMurmur3.Hash_x86_32(Pointer(key)^, Length(Key), Seed);

    if not QueryPerformanceCounter(t2) then t2 := 0;

    WriteLn(
      'Expected = ' + UIntToStr(Expected) + ' (0x' + IntToHex(Expected) +
      ') ; Actual = ' + UIntToStr(actual) + ' (0x' + IntToHex(actual) + ')'
    );
    Status('MurMur > Hashed ' + KeyHexString + ' in ' + FloatToStrF((t2 - t1) / fFreq * 1000000, ffFixed, 15, 3) + ' µs' + sLineBreak + sLineBreak);
    Assert.AreEqual(Expected, actual, Format('Key: %s. Seed: 0x%.8x', [KeyHexString, Seed]));
  end;

  procedure TestString(const Value: string; Seed, Expected: Cardinal);
  var
    actual:    UInt32;
    i:         Integer;
    safeValue: string;
  begin
    if not QueryPerformanceCounter(t1) then t1 := 0;

    actual := TMurmur3.Hash_x86_32(Pointer(Value)^, Length(Value) * SizeOf(Char), Seed);

    if not QueryPerformanceCounter(t2) then t2 := 0;

    //Replace #0 with '#0'. Delphi's StringReplace is unable to replace strings, so we shall do it ourselves
    safeValue := '';

    for i := 1 to Length(Value) do
    begin
      if Value[i] = #0 then
        safeValue := safeValue + '#0'
      else
        safeValue := safeValue + Value[i];
    end;

    WriteLn(
      'Expected = ' + UIntToStr(Expected) + ' (0x' + IntToHex(Expected) +
      ') ; Actual = ' + UIntToStr(actual) + ' (0x' + IntToHex(actual) + ')'
    );
    Status('MurMur > Hashed "' + safeValue + '" in ' + FloatToStrF((t2 - t1) / fFreq * 1000000, ffFixed, 15, 3) + ' µs' + sLineBreak + sLineBreak);
    Assert.AreEqual(Expected, actual, Format('Key: %s. Seed: 0x%.8x', [safeValue, Seed]));
  end;
const
  n: string = ''; //n=nothing.
      //Work around bug in older versions of Delphi compiler when building WideStrings
      //http://stackoverflow.com/a/7031942/12597

begin
  t('',                    0,         0); //with zero data and zero seed; everything becomes zero
  t('',                    1, $514E28B7); //ignores nearly all the math

  t('',            $FFFFFFFF, $81F16F39); //Make sure your seed is using unsigned math
  t('FF FF FF FF',         0, $76293B50); //Make sure your 4-byte chunks are using unsigned math
  t('21 43 65 87',         0, $F55B516B); //Endian order. UInt32 should end up as 0x87654321
  t('21 43 65 87', $5082EDEE, $2362F9DE); //Seed value eliminates initial key with xor

  t(   '21 43 65',         0, $85F0B427); //Only three bytes. Should end up as 0x654321
  t(      '21 43',         0, $30F4C306); //Only two bytes. Should end up as 0x4321
  t(         '21',         0, $72661CF4); //Only one bytes. Should end up as 0x21

  t('00 00 00 00',         0, $2362F9DE); //Zero dword eliminiates almost all math. Make sure you don't mess up the pointers and it ends up as null
  t(   '00 00 00',         0, $85F0B427); //Only three bytes. Should end up as 0.
  t(      '00 00',         0, $30F4C306); //Only two bytes. Should end up as 0.
  t(         '00',         0, $514E28B7); //Only one bytes. Should end up as 0.


  //Easier to test strings. All strings are assumed to be UTF-8 encoded and do not include any null terminator
  TestString('',       0,         0); //empty string with zero seed should give zero
  TestString('',       1,         $514E28B7);
  TestString('',       $ffffffff, $81F16F39); //make sure seed value handled unsigned
  TestString(#0#0#0#0, 0,         $63852AFC); //we handle embedded nulls

  TestString('aaaa', $9747b28c, $157E91C5); //one full chunk
  TestString('a',    $9747b28c, $A8E39363); //one character
  TestString('aa',   $9747b28c, $D881D8ED); //two characters
  TestString('aaa',  $9747b28c, $3615EDFA); //three characters

  //Endian order within the chunks
  TestString('abcd', $9747b28c, $AA4EC2D3); //one full chunk
  TestString('a',    $9747b28c, $A8E39363);
  TestString('ab',   $9747b28c, $15EB70BC);
  TestString('abc',  $9747b28c, $DDDD931B);

  TestString('Hello, world!', $9747b28c, $6FB11145);

  //we build it up this way to workaround a bug in older versions of Delphi that were unable to build WideStrings correctly
  ws := n + #$03C0 + #$03C0 + #$03C0 + #$03C0 + #$03C0 + #$03C0 + #$03C0 + #$03C0; //U+03C0: Greek Small Letter Pi
  TestString(ws, $9747b28c, $48D65952); //Unicode handling and conversion to UTF-8

  {
    String of 256 characters.
    Make sure you don't store string lengths in a char, and overflow at 255.
    OpenBSD's canonical implementation of BCrypt made this mistake
  }
  ws := StringOfChar('a', 256);
  TestString(ws, $9747b28c, $22D36134);


  //The test vector that you'll see out there for Murmur
  TestString('The quick brown fox jumps over the lazy dog', $9747b28c, $55FD8FC4);


  //The SHA2 test vectors
  TestString('abc', 0, $CEE9B502);
  TestString('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq', 0, $50E55785);

  //#1) 1 byte 0xbd
  t('bd', 0, $5FF4C2DA);

  //#2) 4 bytes 0xc98c8e55
  t('55 8e 8c c9', 0, $A7B55574);

  //#3) 55 bytes of zeros (ASCII character 55)
  TestString(StringOfChar('0', 55), 0, 3161883793);

  //#4) 56 bytes of zeros
  TestString(StringOfChar('0', 56), 0, 655514345);

  //#5) 57 bytes of zeros
  TestString(StringOfChar('0', 57), 0, 2594779779);

  //#6) 64 bytes of zeros
  TestString(StringOfChar('0', 64), 0, 1154515581);

  //#7) 1000 bytes of zeros
  TestString(StringOfChar('0', 1000), 0, 1003985660);

  //#8) 1000 bytes of 0x41 ‘A’
  TestString(StringOfChar('A', 1000), 0, 2308940363);

  //#9) 1005 bytes of 0x55 ‘U’
  TestString(StringOfChar('U', 1005), 0, 3110870172);
end;

procedure TMurMur3Tests.SelfTest_MurMur_Three_128_x86_TestVectors;
var
  ws:     string;
  t1, t2: Int64;

  procedure t(const KeyHexString: string; Seed: Cardinal; Expected: string);
  var
    actual: string;
    key:    TByteDynArray;
  begin
    key := HexStringToBytes(KeyHexString);

    if not QueryPerformanceCounter(t1) then t1 := 0;

    actual := TMurmur3.Hash_x86_128(Pointer(key)^, Length(Key), Seed);

    if not QueryPerformanceCounter(t2) then t2 := 0;

    WriteLn('Expected = ' + Expected + ' ; Actual = ' + actual);
    Status('MurMur > Hashed ' + KeyHexString + ' in ' + FloatToStrF((t2 - t1) / fFreq * 1000000, ffFixed, 15, 3) + ' µs' + sLineBreak + sLineBreak);
    Assert.AreEqual(Expected, actual, Format('Key: %s. Seed: 0x%.8x', [KeyHexString, Seed]));
  end;

  procedure TestString(const Value: string; Seed: Cardinal; Expected: string);
  var
    i:         Integer;
    actual,
    safeValue: string;
  begin
    if not QueryPerformanceCounter(t1) then t1 := 0;

    actual := TMurmur3.Hash_x86_128(Pointer(Value)^, Length(Value) * SizeOf(Char), Seed);

    if not QueryPerformanceCounter(t2) then t2 := 0;

    //Replace #0 with '#0'. Delphi's StringReplace is unable to replace strings, so we shall do it ourselves
    safeValue := '';

    for i := 1 to Length(Value) do
    begin
      if Value[i] = #0 then
        safeValue := safeValue + '#0'
      else
        safeValue := safeValue + Value[i];
    end;

    WriteLn('Expected = ' + Expected + ' ; Actual = ' + actual);
    Status('MurMur > Hashed "' + safeValue + '" in ' + FloatToStrF((t2 - t1) / fFreq * 1000000, ffFixed, 15, 3) + ' µs' + sLineBreak + sLineBreak);
    Assert.AreEqual(Expected, actual, Format('Key: %s. Seed: 0x%.8x', [safeValue, Seed]));
  end;
const
  n: string = ''; //n=nothing.
      //Work around bug in older versions of Delphi compiler when building WideStrings
      //http://stackoverflow.com/a/7031942/12597

begin
  t('',                    0, '00000000000000000000000000000000'); //with zero data and zero seed; everything becomes zero
  t('',                    1, '88C4ADEC88C4ADEC88C4ADEC88C4ADEC'); //ignores nearly all the math

  t('',            $FFFFFFFF, '051E08A9051E08A9051E08A9051E08A9'); //Make sure your seed is using unsigned math
  t('FF FF FF FF',         0, 'CC066F1FCC066F1FCC066F1FCC066F1F'); //Make sure your 4-byte chunks are using unsigned math
  t('21 43 65 87',         0, 'CC066F1FCC066F1FCC066F1FCC066F1F'); //Endian order. UInt32 should end up as 0x87654321
  t('21 43 65 87', $5082EDEE, '91F761DC91F761DC91F761DC91F761DC'); //Seed value eliminates initial key with xor

  t(   '21 43 65',         0, 'E0D93642E0D93642E0D93642E0D93642'); //Only three bytes. Should end up as 0x654321
  t(      '21 43',         0, '04A872BB04A872BB04A872BB04A872BB'); //Only two bytes. Should end up as 0x4321
  t(         '21',         0, '5D658BC35D658BC35D658BC35D658BC3'); //Only one bytes. Should end up as 0x21

  t('00 00 00 00',         0, 'CC066F1FCC066F1FCC066F1FCC066F1F'); //Zero dword eliminiates almost all math. Make sure you don't mess up the pointers and it ends up as null
  t(   '00 00 00',         0, 'E0D93642E0D93642E0D93642E0D93642'); //Only three bytes. Should end up as 0.
  t(      '00 00',         0, '04A872BB04A872BB04A872BB04A872BB'); //Only two bytes. Should end up as 0.
  t(         '00',         0, '88C4ADEC88C4ADEC88C4ADEC88C4ADEC'); //Only one bytes. Should end up as 0.


  //Easier to test strings. All strings are assumed to be UTF-8 encoded and do not include any null terminator
  TestString('',               0, '00000000000000000000000000000000'); //empty string with zero seed should give zero
  TestString('',               1, '88C4ADEC88C4ADEC88C4ADEC88C4ADEC');
  TestString('',       $ffffffff, '051E08A9051E08A9051E08A9051E08A9'); //make sure seed value handled unsigned
  TestString(#0#0#0#0,         0, 'E028AE41E028AE41E028AE41E028AE41'); //we handle embedded nulls

  TestString('aaaa', $9747b28c, '0D5969710D5969710D5969710D596971'); //one full chunk
  TestString('a',    $9747b28c, 'C3599F1AC3599F1AC3599F1AC3599F1A'); //one character
  TestString('aa',   $9747b28c, '70E8B0F870E8B0F870E8B0F870E8B0F8'); //two characters
  TestString('aaa',  $9747b28c, '7B2DD11C7B2DD11C7B2DD11C7B2DD11C'); //three characters

  //Endian order within the chunks
  TestString('abcd', $9747b28c, '0D5969710D5969710D5969710D596971'); //one full chunk
  TestString('a',    $9747b28c, 'C3599F1AC3599F1AC3599F1AC3599F1A');
  TestString('ab',   $9747b28c, '70E8B0F870E8B0F870E8B0F870E8B0F8');
  TestString('abc',  $9747b28c, '7B2DD11C7B2DD11C7B2DD11C7B2DD11C');

  TestString('Hello, world!', $9747b28c, '169EC9209D5AB4D2EADF12FD169EC920');

  //we build it up this way to workaround a bug in older versions of Delphi that were unable to build WideStrings correctly
  ws := n + #$03C0 + #$03C0 + #$03C0 + #$03C0 + #$03C0 + #$03C0 + #$03C0 + #$03C0; //U+03C0: Greek Small Letter Pi
  TestString(ws, $9747b28c, '2C3CA29F5217AA84EB8882D12C3CA29F'); //Unicode handling and conversion to UTF-8

  {
    String of 256 characters.
    Make sure you don't store string lengths in a char, and overflow at 255.
    OpenBSD's canonical implementation of BCrypt made this mistake
  }
  ws := StringOfChar('a', 256);
  TestString(ws, $9747b28c, '6FA64859FA1315E22FDB69546FA64859');


  //The test vector that you'll see out there for Murmur
  TestString('The quick brown fox jumps over the lazy dog', $9747b28c, '7AB5455B2E3E45E706081B397AB5455B');


  //The SHA2 test vectors
  TestString('abc', 0, '777FA956777FA956777FA956777FA956');
  TestString('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq', 0, '6BC39236CF45E21AAAB6A28A6BC39236');

  //#1) 1 byte 0xbd
  t('bd', 0, '0A8C9F770A8C9F770A8C9F770A8C9F77');

  //#2) 4 bytes 0xc98c8e55
  t('55 8e 8c c9', 0, 'CC066F1FCC066F1FCC066F1FCC066F1F');

  //#3) 55 bytes of zeros (ASCII character 55)
  TestString(StringOfChar('0', 55), 0, '80243F2CE1D7A811C2838B1A80243F2C');

  //#4) 56 bytes of zeros
  TestString(StringOfChar('0', 56), 0, '862574C77D3DCC0C6756CA99862574C7');

  //#5) 57 bytes of zeros
  TestString(StringOfChar('0', 57), 0, 'E4B09A88D92DE8564B1553D5E4B09A88');

  //#6) 64 bytes of zeros
  TestString(StringOfChar('0', 64), 0, '8889CE3DB70EDDF1810795488889CE3D');

  //#7) 1000 bytes of zeros
  TestString(StringOfChar('0', 1000), 0, 'FCBF847E95478919A5E5EA3BFCBF847E');

  //#8) 1000 bytes of 0x41 ‘A’
  TestString(StringOfChar('A', 1000), 0, 'AAA4FB1BD9D6A967EEB5EEAAAAA4FB1B');

  //#9) 1005 bytes of 0x55 ‘U’
  TestString(StringOfChar('U', 1005), 0, '3DEB3FB8622A8435BA1152263DEB3FB8');
end;

procedure TMurMur3Tests.SelfTest_MurMur_Three_128_x64_TestVectors;
var
  ws:     string;
  t1, t2: Int64;

  procedure t(const KeyHexString: string; Seed: Cardinal; Expected: string);
  var
    actual: string;
    key:    TByteDynArray;
  begin
    key := HexStringToBytes(KeyHexString);

    if not QueryPerformanceCounter(t1) then t1 := 0;

    actual := TMurmur3.Hash_x64_128(Pointer(key)^, Length(Key), Seed);

    if not QueryPerformanceCounter(t2) then t2 := 0;

    WriteLn('Expected = ' + Expected + ' ; Actual = ' + actual);
    Status('MurMur > Hashed ' + KeyHexString + ' in ' + FloatToStrF((t2 - t1) / fFreq * 1000000, ffFixed, 15, 3) + ' µs' + sLineBreak + sLineBreak);
    Assert.AreEqual(Expected, actual, Format('Key: %s. Seed: 0x%.8x', [KeyHexString, Seed]));
  end;

  procedure TestString(const Value: string; Seed: Cardinal; Expected: string);
  var
    i:         Integer;
    actual,
    safeValue: string;
  begin
    if not QueryPerformanceCounter(t1) then t1 := 0;

    actual := TMurmur3.Hash_x64_128(Pointer(Value)^, Length(Value) * SizeOf(Char), Seed);

    if not QueryPerformanceCounter(t2) then t2 := 0;

    //Replace #0 with '#0'. Delphi's StringReplace is unable to replace strings, so we shall do it ourselves
    safeValue := '';

    for i := 1 to Length(Value) do
    begin
      if Value[i] = #0 then
        safeValue := safeValue + '#0'
      else
        safeValue := safeValue + Value[i];
    end;

    WriteLn('Expected = ' + Expected + ' ; Actual = ' + actual);
    Status('MurMur > Hashed "' + safeValue + '" in ' + FloatToStrF((t2 - t1) / fFreq * 1000000, ffFixed, 15, 3) + ' µs' + sLineBreak + sLineBreak);
    Assert.AreEqual(Expected, actual, Format('Key: %s. Seed: 0x%.8x', [safeValue, Seed]));
  end;
const
  n: string = ''; //n=nothing.
      //Work around bug in older versions of Delphi compiler when building WideStrings
      //http://stackoverflow.com/a/7031942/12597

begin
  t('',                    0, '00000000000000000000000000000000'); //with zero data and zero seed; everything becomes zero
  t('',                    1, ''); //ignores nearly all the math

  t('',            $FFFFFFFF, ''); //Make sure your seed is using unsigned math
  t('FF FF FF FF',         0, ''); //Make sure your 4-byte chunks are using unsigned math
  t('21 43 65 87',         0, ''); //Endian order. UInt32 should end up as 0x87654321
  t('21 43 65 87', $5082EDEE, ''); //Seed value eliminates initial key with xor

  t(   '21 43 65',         0, ''); //Only three bytes. Should end up as 0x654321
  t(      '21 43',         0, ''); //Only two bytes. Should end up as 0x4321
  t(         '21',         0, ''); //Only one bytes. Should end up as 0x21

  t('00 00 00 00',         0, ''); //Zero dword eliminiates almost all math. Make sure you don't mess up the pointers and it ends up as null
  t(   '00 00 00',         0, ''); //Only three bytes. Should end up as 0.
  t(      '00 00',         0, ''); //Only two bytes. Should end up as 0.
  t(         '00',         0, ''); //Only one bytes. Should end up as 0.


  //Easier to test strings. All strings are assumed to be UTF-8 encoded and do not include any null terminator
  TestString('',               0, '00000000000000000000000000000000'); //empty string with zero seed should give zero
  TestString('',               1, '');
  TestString('',       $ffffffff, ''); //make sure seed value handled unsigned
  TestString(#0#0#0#0,         0, ''); //we handle embedded nulls

  TestString('aaaa', $9747b28c, ''); //one full chunk
  TestString('a',    $9747b28c, ''); //one character
  TestString('aa',   $9747b28c, ''); //two characters
  TestString('aaa',  $9747b28c, ''); //three characters

  //Endian order within the chunks
  TestString('abcd', $9747b28c, ''); //one full chunk
  TestString('a',    $9747b28c, '');
  TestString('ab',   $9747b28c, '');
  TestString('abc',  $9747b28c, '');

  TestString('Hello, world!', $9747b28c, '');

  //we build it up this way to workaround a bug in older versions of Delphi that were unable to build WideStrings correctly
  ws := n + #$03C0 + #$03C0 + #$03C0 + #$03C0 + #$03C0 + #$03C0 + #$03C0 + #$03C0; //U+03C0: Greek Small Letter Pi
  TestString(ws, $9747b28c, ''); //Unicode handling and conversion to UTF-8

  {
    String of 256 characters.
    Make sure you don't store string lengths in a char, and overflow at 255.
    OpenBSD's canonical implementation of BCrypt made this mistake
  }
  ws := StringOfChar('a', 256);
  TestString(ws, $9747b28c, '');


  //The test vector that you'll see out there for Murmur
  TestString('The quick brown fox jumps over the lazy dog', $9747b28c, '');


  //The SHA2 test vectors
  TestString('abc', 0, '');
  TestString('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq', 0, '');

  //#1) 1 byte 0xbd
  t('bd', 0, '');

  //#2) 4 bytes 0xc98c8e55
  t('55 8e 8c c9', 0, '');

  //#3) 55 bytes of zeros (ASCII character 55)
  TestString(StringOfChar('0', 55), 0, '');

  //#4) 56 bytes of zeros
  TestString(StringOfChar('0', 56), 0, '');

  //#5) 57 bytes of zeros
  TestString(StringOfChar('0', 57), 0, '');

  //#6) 64 bytes of zeros
  TestString(StringOfChar('0', 64), 0, '');

  //#7) 1000 bytes of zeros
  TestString(StringOfChar('0', 1000), 0, '');

  //#8) 1000 bytes of 0x41 ‘A’
  TestString(StringOfChar('A', 1000), 0, '');

  //#9) 1005 bytes of 0x55 ‘U’
  TestString(StringOfChar('U', 1005), 0, '');
end;

procedure TMurMur3Tests.SetUp;
begin
  if not QueryPerformanceFrequency(fFreq) then
    fFreq := -1;
end;

initialization
  TDUnitX.RegisterTestFixture(TMurMur3Tests);

end.
