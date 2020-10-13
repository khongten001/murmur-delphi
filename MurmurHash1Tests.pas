unit MurMurHash1Tests;
interface
uses
	DUnitX.TestFramework, SysUtils, MurMurHash;

type
  [TestFixture]
	TMurMur1Tests = class(TObject)
	protected
		fFreq: Int64;
	public
    [Setup]
		procedure SetUp;
    [TestCase('Canonical MurMur1 Hash', '')]
		procedure SelfTest_Canonical_MurMur_One_Hash;
    [TestCase('Canonical MurMur1 HashAligned', '')]
		procedure SelfTest_Canonical_MurMur_One_HashAligned;
    [TestCase('32-bit Test Vectors', '')]
		procedure SelfTest_MurMur_One_TestVectors;
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

{ TMurMur1Tests }

(*
  The canonical Murmur1 tests are to perform multiple hashes, then hash the result of the hashes.

  Expected Result: 0xB0F57EE3
    main.cpp
    https://github.com/rurban/smhasher/blob/9c9619c3beef4241e8e96305fbbee3ec069d3081/main.cpp

  Hash keys of the form {0}, {0,1}, {0,1,2}... up to N=255,
  using 256-N as the seed

  Key	              Seed         Hash
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
procedure TMurMur1Tests.SelfTest_Canonical_MurMur_One_Hash;
const
  Expected: Cardinal = $99C0243B;
var
	key:    array[0..255] of Byte;     //256 hashes
	hashes: array[0..256] of Cardinal; //result of each of the 256 hashes
	i:      Integer;
	actual: Cardinal;
	t1, t2: Int64;
begin
  Log('Using TMurmur1.Hash > Hashing 256 values, followed by hashing the result set of the hashes');

	if not QueryPerformanceCounter({out}t1) then
		t1 := 0;

	for i := 0 to 255 do
	begin
		key[i]    := Byte(i);
		hashes[i] := TMurmur1.Hash(key[0], i, 256 - i);
	end;

	actual := TMurmur1.Hash(hashes[0], 256 * SizeOf(Cardinal), 0);

	if not QueryPerformanceCounter({out}t2) then
		t2 := 0;

  WriteLn(
    'Expected = ' + UIntToStr(Expected) + ' (0x' + IntToHex(Expected) +
    ') ; Actual = ' + UIntToStr(actual) + ' (0x' + IntToHex(actual) + ')'
  );
	Status('Test completed in ' + FloatToStrF((t2 - t1) / fFreq * 1000000, ffFixed, 15, 3) + ' µs' + sLineBreak + sLineBreak);
  Assert.AreEqual(Expected, Actual); // testcode
end;

procedure TMurMur1Tests.SelfTest_Canonical_MurMur_One_HashAligned;
const
  Expected: Cardinal = $99C0243B;
var
	key:    array[0..255] of Byte;     //256 hashes
	hashes: array[0..256] of Cardinal; //result of each of the 256 hashes
	i:      Integer;
	actual: Cardinal;
	t1, t2: Int64;
begin
  Log('Using TMurmur1.HashAligned > Hashing 256 values, followed by hashing the result set of the hashes');

	if not QueryPerformanceCounter({out}t1) then
		t1 := 0;

	for i := 0 to 255 do
	begin
		key[i]    := Byte(i);
		hashes[i] := TMurmur1.HashAligned(key[0], i, 256 - i);
	end;

	actual := TMurmur1.HashAligned(hashes[0], 256 * SizeOf(Cardinal), 0);

	if not QueryPerformanceCounter({out}t2) then
		t2 := 0;

  WriteLn(
    'Expected = ' + UIntToStr(Expected) + ' (0x' + IntToHex(Expected) +
    ') ; Actual = ' + UIntToStr(actual) + ' (0x' + IntToHex(actual) + ')'
  );
	Status('Test completed in ' + FloatToStrF((t2 - t1) / fFreq * 1000000, ffFixed, 15, 3) + ' µs' + sLineBreak + sLineBreak);
  Assert.AreEqual(Expected, Actual); // testcode
end;

procedure TMurMur1Tests.SelfTest_MurMur_One_TestVectors;
var
	ws: string;
	t1, t2: Int64;

	procedure t(const KeyHexString: string; Seed: Cardinal; Expected: Cardinal);
	var
		actual: LongWord;
		key:    TByteDynArray;
	begin
		key := HexStringToBytes(KeyHexString);

		if not QueryPerformanceCounter(t1) then t1 := 0;

		actual := TMurmur1.Hash(Pointer(key)^, Length(Key), Seed);

		if not QueryPerformanceCounter(t2) then t2 := 0;

    WriteLn(
      'Expected = ' + UIntToStr(Expected) + ' (0x' + IntToHex(Expected) +
      ') ; Actual = ' + UIntToStr(actual) + ' (0x' + IntToHex(actual) + ')'
    );
		Status('MurMur > Hashed ' + KeyHexString + ' in ' + FloatToStrF((t2 - t1) / fFreq * 1000000, ffFixed, 15, 3) + ' µs' + sLineBreak + sLineBreak);
		Assert.AreEqual(Expected, actual, Format('Key: %s. Seed: 0x%.8x', [KeyHexString, Seed]));
	end;

	procedure TestString(const Value: string; Seed: Cardinal; Expected: Cardinal);
	var
		actual:    LongWord;
		i:         Integer;
		safeValue: string;
	begin
		if not QueryPerformanceCounter(t1) then t1 := 0;

		actual := TMurmur1.Hash(Pointer(Value)^, Length(Value) * SizeOf(WideChar), Seed);

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
	t('',                    1, $8F5A8D63); //ignores nearly all the math

	t('',            $FFFFFFFF, $7A3F4F7E); //Make sure your seed is using unsigned math
	t('FF FF FF FF',         0, $219738A7); //Make sure your 4-byte chunks are using unsigned math
	t('21 43 65 87',         0, $2D0F8B30); //Endian order. UInt32 should end up as 0x87654321
	t('21 43 65 87', $5082EDEE, $794998F3); //Seed value eliminates initial key with xor

	t(   '21 43 65',         0, $C82D0141); //Only three bytes. Should end up as 0x654321
	t(      '21 43',         0, $5F66FF1E); //Only two bytes. Should end up as 0x4321
	t(         '21',         0, $2940649F); //Only one bytes. Should end up as 0x21

	t('00 00 00 00',         0, $EB4ED66A); //Zero dword eliminiates almost all math. Make sure you don't mess up the pointers and it ends up as null
	t(   '00 00 00',         0, $1E460534); //Only three bytes. Should end up as 0.
	t(      '00 00',         0, $333C11F9); //Only two bytes. Should end up as 0.
	t(         '00',         0, $8837CF3E); //Only one bytes. Should end up as 0.


	//Easier to test strings. All strings are assumed to be UTF-8 encoded and do not include any null terminator
	TestString('',       0,         0); //empty string with zero seed should give zero
	TestString('',       1,         $8F5A8D63);
	TestString('',       $ffffffff, $7A3F4F7E); //make sure seed value handled unsigned
	TestString(#0#0#0#0, 0,         $1FC6945B); //we handle embedded nulls

	TestString('aaaa', $9747b28c, $E3A2199B); //one full chunk
	TestString('a',    $9747b28c, $C0F5DF3D); //one character
	TestString('aa',   $9747b28c, $8D43FC88); //two characters
	TestString('aaa',  $9747b28c, $E9B4440B); //three characters

	//Endian order within the chunks
	TestString('abcd', $9747b28c, $A78F9530); //one full chunk
	TestString('a',    $9747b28c, $C0F5DF3D);
	TestString('ab',   $9747b28c, $CF9066BA);
	TestString('abc',  $9747b28c, $B089705D);

	TestString('Hello, world!', $9747b28c, $6279B6C7);

	//we build it up this way to workaround a bug in older versions of Delphi that were unable to build WideStrings correctly
	ws := n + #$03C0 + #$03C0 + #$03C0 + #$03C0 + #$03C0 + #$03C0 + #$03C0 + #$03C0; //U+03C0: Greek Small Letter Pi
	TestString(ws, $9747b28c, $96115734); //Unicode handling and conversion to UTF-8

	{
		String of 256 characters.
		Make sure you don't store string lengths in a char, and overflow at 255.
		OpenBSD's canonical implementation of BCrypt made this mistake
	}
	ws := StringOfChar('a', 256);
	TestString(ws, $9747b28c, $45F03BEF);


	//The test vector that you'll see out there for Murmur
	TestString('The quick brown fox jumps over the lazy dog', $9747b28c, $025A8B4A);


	//The SHA2 test vectors
	TestString('abc', 0, $998E3B72);
	TestString('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq', 0, $CD4252FF);

	//#1) 1 byte 0xbd
	t('bd', 0, $BAC6BDB1);

	//#2) 4 bytes 0xc98c8e55
	t('55 8e 8c c9', 0, $F674766B);

	//#3) 55 bytes of zeros (ASCII character 55)
	TestString(StringOfChar('0', 55), 0, 1699016170);

	//#4) 56 bytes of zeros
	TestString(StringOfChar('0', 56), 0, 2793276253);

	//#5) 57 bytes of zeros
	TestString(StringOfChar('0', 57), 0, 2785633196);

	//#6) 64 bytes of zeros
	TestString(StringOfChar('0', 64), 0, 1294100748);

	//#7) 1000 bytes of zeros
	TestString(StringOfChar('0', 1000), 0, 729562938);

	//#8) 1000 bytes of 0x41 ‘A’
	TestString(StringOfChar('A', 1000), 0, 66908384);

	//#9) 1005 bytes of 0x55 ‘U’
	TestString(StringOfChar('U', 1005), 0, 2111496562);
end;

procedure TMurmur1Tests.SetUp;
begin
	if not QueryPerformanceFrequency(fFreq) then
		fFreq := -1;
end;

initialization
  TDUnitX.RegisterTestFixture(TMurMur1Tests);

end.
