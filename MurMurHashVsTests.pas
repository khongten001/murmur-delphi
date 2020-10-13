unit MurMurHashVsTests;
interface
uses
	DUnitX.TestFramework, SysUtils, MurMurHash;

type
  [TestFixture]
	TMurMurVsTests = class(TObject)
	protected
		fFreq: Int64;
	public
    [Setup]
		procedure SetUp;
    [TearDown]
		procedure TearDown;
    [TestCase('Life-like Test Vectors', '')]
		procedure SelfTest_MurMur_One_LifeLike_TestVectors;
	end;

implementation
uses
	Types, Windows, System.Hash;

function Adler32CRC(TextPointer: Pointer; TextLength: Cardinal): Cardinal;
var
  I, A, B: Cardinal;
begin
  A := 1;
  B := 0; // A is initialized to 1, B to 0

  for I := 1 to TextLength do
  begin
    Inc(A, PByte(Cardinal(TextPointer) + I - 1)^);
    Inc(B, A);
  end;

  A      := A mod 65521; // 65521 (the largest prime number smaller than 2^16)
  B      := B mod 65521;
  Result := B + A shl 16; // reverse order for smaller numbers
end;

{ TMurMurVsTests }

procedure TMurMurVsTests.SelfTest_MurMur_One_LifeLike_TestVectors;
var
	t1, t2: Int64;

	procedure TestStringBobJenkins(const Value, SafeValue: string);
  var
    actual: Integer;
	begin
		if not QueryPerformanceCounter(t1) then t1 := 0;

		actual := THashBobJenkins.GetHashValue(Value);

		if not QueryPerformanceCounter(t2) then t2 := 0;

    WriteLn('Actual = ' + UIntToStr(actual) + ' (0x' + IntToHex(actual) + ')');
		Status('BobJenkins > Hashed "' + SafeValue + '" in ' + FloatToStrF((t2 - t1) / fFreq * 1000000, ffFixed, 15, 3) + ' µs' + sLineBreak + sLineBreak);
	end;

	procedure TestStringAdler32CRC(const Value, SafeValue: string);
  var
    actual: Cardinal;
	begin
		if not QueryPerformanceCounter(t1) then t1 := 0;

		actual := Adler32CRC(PChar(Value), Length(Value) * SizeOf(Char));

		if not QueryPerformanceCounter(t2) then t2 := 0;

    WriteLn('Actual = ' + UIntToStr(actual) + ' (0x' + IntToHex(actual) + ')');
		Status('Adler32CRC > Hashed "' + SafeValue + '" in ' + FloatToStrF((t2 - t1) / fFreq * 1000000, ffFixed, 15, 3) + ' µs' + sLineBreak + sLineBreak);
	end;

	procedure TestStringMurMur3(const Value, SafeValue: string; Seed: Cardinal);
  var
    actual: UInt64;
	begin
		if not QueryPerformanceCounter(t1) then t1 := 0;

		actual := TMurmur3.Hash(PChar(Value)^, Length(Value) * SizeOf(Char), Seed);

		if not QueryPerformanceCounter(t2) then t2 := 0;

    WriteLn('Actual = ' + UIntToStr(actual) + ' (0x' + IntToHex(actual) + ')');
		Status('MurMur3.Hash > Hashed "' + SafeValue + '" in ' + FloatToStrF((t2 - t1) / fFreq * 1000000, ffFixed, 15, 3) + ' µs' + sLineBreak + sLineBreak);
	end;

	procedure TestStringMurMur2(const Value, SafeValue: string; Seed: Cardinal);
  var
    actual: UInt32;
    actual64: UInt64;
	begin
		if not QueryPerformanceCounter(t1) then t1 := 0;

		actual := TMurmur2.Hash(PChar(Value)^, Length(Value) * SizeOf(Char), Seed);

		if not QueryPerformanceCounter(t2) then t2 := 0;

    WriteLn('Actual = ' + UIntToStr(actual) + ' (0x' + IntToHex(actual) + ')');
		Status('MurMur2.Hash > Hashed "' + SafeValue + '" in ' + FloatToStrF((t2 - t1) / fFreq * 1000000, ffFixed, 15, 3) + ' µs' + sLineBreak + sLineBreak);

		if not QueryPerformanceCounter(t1) then t1 := 0;

		actual := TMurmur2.HashA(PChar(Value)^, Length(Value) * SizeOf(Char), Seed);

		if not QueryPerformanceCounter(t2) then t2 := 0;

    WriteLn('Actual = ' + UIntToStr(actual) + ' (0x' + IntToHex(actual) + ')');
		Status('MurMur2.HashA > Hashed "' + SafeValue + '" in ' + FloatToStrF((t2 - t1) / fFreq * 1000000, ffFixed, 15, 3) + ' µs' + sLineBreak + sLineBreak);

		if not QueryPerformanceCounter(t1) then t1 := 0;

		actual64 := TMurmur2.Hash64A(PChar(Value)^, Length(Value) * SizeOf(Char), Seed);

		if not QueryPerformanceCounter(t2) then t2 := 0;

    WriteLn('Actual64 = ' + UIntToStr(actual64) + ' (0x' + IntToHex(actual64) + ')');
		Status('MurMur2.Hash64A > Hashed "' + SafeValue + '" in ' + FloatToStrF((t2 - t1) / fFreq * 1000000, ffFixed, 15, 3) + ' µs' + sLineBreak + sLineBreak);

		if not QueryPerformanceCounter(t1) then t1 := 0;

		actual64 := TMurmur2.Hash64B(PChar(Value)^, Length(Value) * SizeOf(Char), Seed);

		if not QueryPerformanceCounter(t2) then t2 := 0;

    WriteLn('Actual64 = ' + UIntToStr(actual64) + ' (0x' + IntToHex(actual64) + ')');
		Status('MurMur2.Hash64B > Hashed "' + SafeValue + '" in ' + FloatToStrF((t2 - t1) / fFreq * 1000000, ffFixed, 15, 3) + ' µs' + sLineBreak + sLineBreak);
	end;

	procedure TestStringMurMur1(const Value, SafeValue: string; Seed: Cardinal);
  var
    actual: UInt32;
	begin
		if not QueryPerformanceCounter(t1) then t1 := 0;

		actual := TMurmur1.Hash(PChar(Value)^, Length(Value) * SizeOf(Char), Seed);

		if not QueryPerformanceCounter(t2) then t2 := 0;

    WriteLn('Actual = ' + UIntToStr(actual) + ' (0x' + IntToHex(actual) + ')');
		Status('MurMur1.Hash > Hashed "' + SafeValue + '" in ' + FloatToStrF((t2 - t1) / fFreq * 1000000, ffFixed, 15, 3) + ' µs' + sLineBreak + sLineBreak);
	end;

	procedure TestString(const Value: string; Seed: Cardinal);
  var
		safeValue: string;
		I:         Integer;
  begin
		//Replace #0 with '#0'. Delphi's StringReplace is unable to replace strings, so we shall do it ourselves
		safeValue := '';

		for I := 1 to Length(Value) do
		begin
			if Value[I] = #0 then
				safeValue := safeValue + '#0'
			else
				safeValue := safeValue + Value[I];
		end;

    TestStringMurMur1(Value, safeValue, Seed);
    TestStringMurMur2(Value, safeValue, Seed);
    TestStringMurMur3(Value, safeValue, Seed);
    TestStringAdler32CRC(Value, safeValue);
    TestStringBobJenkins(Value, safeValue);
  end;

const
  BASIC_MAP_DAT = 'IVZFUlNJT04gMw0KDQovLyBHZW5lcmFsIHNldHRpbmdzDQohUkFOS0lORyAwIC8v' +
                  'IERpc2FibGVkDQohSEFORFNfQ09VTlQgNg0KIUhBTkRfREVGQVVMVF9IVU1BTiAw' +
                  'DQoNCi8vIEhhbmRzDQotLS0tLUhhbmQwLS0tLS0NCiFIQU5EX0NVUlJFTlQgMA0K' +
                  'IUhBTkRfQUxMT1dfSFVNQU4NCiFIQU5EX0FMTE9XX0FJDQohSEFORF9BQ1RJVkFU' +
                  'RQ0KIUhBTkRfQ09MT1IgNDYwNzk5DQohSEFORF9DRU5URVJfU0NSRUVOIDQzIDQ2' +
                  'DQoNCi8vIEZvZyBvZiBXYXINCg0KLy8gR29hbHMNCiFBRERfR09BTCAxIDEgMCAw' +
                  'IDENCg0KLy8gQUkNCiFTRVRfQUlfQVVUT19SRVBBSVINCiFTRVRfQUlfQ0hBUkFD' +
                  'VEVSIFNFUkZTX1BFUl8xMF9IT1VTRVMgMTANCiFTRVRfQUlfQ0hBUkFDVEVSIEJV' +
                  'SUxERVJTX0NPVU5UIDEyDQoNCi8vIEFsbGlhbmNlcw0KIVNFVF9BTExJQU5DRSAx' +
                  'IDENCiFTRVRfQUxMSUFOQ0UgMiAwDQohU0VUX0FMTElBTkNFIDMgMA0KDQovLyBH' +
                  'cmFudC9CbG9jayBob3VzZXMNCiFIT1VTRV9CTE9DSyAxIC8vIGZvdW5kcnkNCiFI' +
                  'T1VTRV9CTE9DSyAyIC8vIFdlYXBvblNtaXRoeQ0KIUhPVVNFX0JMT0NLIDMgLy8g' +
                  'Y29hbG1ha2Vycw0KIUhPVVNFX0JMT0NLIDQgLy8gSXJvbk1pbmUNCiFIT1VTRV9C' +
                  'TE9DSyA1IC8vIEdvbGRNaW5lDQohSE9VU0VfQkxPQ0sgNiAvLyBmaXNoZXJtYW5z' +
                  'DQohSE9VU0VfQkxPQ0sgNyAvLyBiYWtlcnkNCiFIT1VTRV9CTE9DSyA4IC8vIGZh' +
                  'cm0NCiFIT1VTRV9CTE9DSyA5IC8vIHdvb2RjdXR0ZXJzDQohSE9VU0VfQkxPQ0sg' +
                  'MTAgLy8gQXJtb3JTbWl0aHkNCiFIT1VTRV9CTE9DSyAxMSAvLyBjYW1wDQohSE9V' +
                  'U0VfQkxPQ0sgMTIgLy8gc3RhYmxlcw0KIUhPVVNFX0JMT0NLIDEzIC8vIHNjaG9v' +
                  'bA0KIUhPVVNFX0JMT0NLIDE0IC8vIHN0b25lY3V0dGVycw0KIUhPVVNFX0JMT0NL' +
                  'IDE1IC8vIG1pbnQNCiFIT1VTRV9CTE9DSyAxNiAvLyBjYXR0bGVmYXJtDQohSE9V' +
                  'U0VfQkxPQ0sgMTcgLy8gdG93ZXJfYXJyb3cNCiFIT1VTRV9CTE9DSyAxOSAvLyBX' +
                  'ZWFwb25Xb3Jrc2hvcA0KIUhPVVNFX0JMT0NLIDIwIC8vIEFybW9yV29ya3Nob3AN' +
                  'CiFIT1VTRV9CTE9DSyAyMSAvLyBiYXJyYWNrcw0KIUhPVVNFX0JMT0NLIDIyIC8v' +
                  'IG1pbGwNCiFIT1VTRV9CTE9DSyAyMyAvLyBTaWVnZVdvcmtzaG9wDQohSE9VU0Vf' +
                  'QkxPQ0sgMjQgLy8gYnV0Y2hlcnMNCiFIT1VTRV9CTE9DSyAyNSAvLyB0YW5uZXJ5' +
                  'DQohSE9VU0VfQkxPQ0sgMjYgLy8gc3RvcmUNCiFIT1VTRV9CTE9DSyAyNyAvLyB0' +
                  'YXZlcm4NCiFIT1VTRV9CTE9DSyAyOCAvLyBicmV3ZXJ5DQohSE9VU0VfQkxPQ0sg' +
                  'MjkgLy8gbWFya2V0cGxhY2UNCiFIT1VTRV9CTE9DSyAzMCAvLyBmb3J0DQohSE9V' +
                  'U0VfQkxPQ0sgMzEgLy8gdG93ZXIyDQohSE9VU0VfQkxPQ0sgMzIgLy8gY2lkZXJN' +
                  'YWtlcg0KIUhPVVNFX0JMT0NLIDMzIC8vIHNhd21pbGwNCiFIT1VTRV9CTE9DSyAz' +
                  'NyAvLyBjb3R0YWdlDQoNCi8vIEJsb2NrIHVuaXRzDQohVU5JVF9CTE9DSyA1IC8v' +
                  'IG1pbmVyDQohVU5JVF9CTE9DSyA2IC8vIGJyZWVkZXINCiFVTklUX0JMT0NLIDEw' +
                  'IC8vIGJ1dGNoZXINCiFVTklUX0JMT0NLIDE1IC8vIHNtaXRoDQohVU5JVF9CTE9D' +
                  'SyAxNiAvLyBtZXRhbGx1cmcNCiFVTklUX0JMT0NLIDE4IC8vIG1pbGl0aWENCiFV' +
                  'TklUX0JMT0NLIDE5IC8vIGF4ZWZpZ2h0ZXINCiFVTklUX0JMT0NLIDIwIC8vIHN3' +
                  'b3Jkc21hbg0KIVVOSVRfQkxPQ0sgMjEgLy8gYm93bWFuDQohVU5JVF9CTE9DSyAy' +
                  'MiAvLyBhcmJhbGV0bWFuDQohVU5JVF9CTE9DSyAyMyAvLyBwaWtlbWFuDQohVU5J' +
                  'VF9CTE9DSyAyNCAvLyBoYWxsZWJhcmRtYW4NCiFVTklUX0JMT0NLIDI1IC8vIGhv' +
                  'cnNlc2NvdXQNCiFVTklUX0JMT0NLIDI2IC8vIGNhdmFscnkNCiFVTklUX0JMT0NL' +
                  'IDMyIC8vIHdhZ29uDQoNCi8vIEJsb2NrIHRyYWRlcw0KDQovLyBSb2FkcyBhbmQg' +
                  'ZmllbGRzDQoNCg0KLy8gRmVuY2VzDQoNCg0KLy8gVW5pdHMNCg0KLy8gR3JvdXBz' +
                  'DQohU0VUX0dST1VQIDI2IDQzIDQ2IDcgMSAxIC8vIGNhdmFscnkNCg0KLS0tLS1I' +
                  'YW5kMS0tLS0tDQohSEFORF9DVVJSRU5UIDENCiFIQU5EX0FMTE9XX0FJDQohSEFO' +
                  'RF9BQ1RJVkFURQ0KIUhBTkRfQUlfQ0hBUkFDVEVSIDANCiFIQU5EX0NPTE9SIDI1' +
                  'MDg3DQohSEFORF9DRU5URVJfU0NSRUVOIDEzIDM1DQoNCi8vIEZvZyBvZiBXYXIN' +
                  'Cg0KLy8gR29hbHMNCg0KLy8gQUkNCiFTRVRfQUlfQVVUT19SRVBBSVINCiFTRVRf' +
                  'QUlfQ0hBUkFDVEVSIFNFUkZTX1BFUl8xMF9IT1VTRVMgMTANCiFTRVRfQUlfQ0hB' +
                  'UkFDVEVSIEJVSUxERVJTX0NPVU5UIDEyDQoNCi8vIEFsbGlhbmNlcw0KIVNFVF9B' +
                  'TExJQU5DRSAwIDENCiFTRVRfQUxMSUFOQ0UgMiAxDQohU0VUX0FMTElBTkNFIDMg' +
                  'MQ0KDQovLyBHcmFudC9CbG9jayBob3VzZXMNCiFIT1VTRV9CTE9DSyAyMyAvLyBT' +
                  'aWVnZVdvcmtzaG9wDQohSE9VU0VfQkxPQ0sgMjkgLy8gbWFya2V0cGxhY2UNCg0K' +
                  'Ly8gQmxvY2sgdW5pdHMNCg0KLy8gQmxvY2sgdHJhZGVzDQoNCi8vIFJvYWRzIGFu' +
                  'ZCBmaWVsZHMNCg0KDQovLyBGZW5jZXMNCg0KDQovLyBVbml0cw0KDQovLyBHcm91' +
                  'cHMNCiFTRVRfR1JPVVAgMjYgMTkgMzcgMiAxIDEgLy8gY2F2YWxyeQ0KDQotLS0t' +
                  'LUhhbmQyLS0tLS0NCiFIQU5EX0NVUlJFTlQgMg0KIUhBTkRfQUxMT1dfQUkNCiFI' +
                  'QU5EX0FDVElWQVRFDQohSEFORF9BSV9DSEFSQUNURVIgMA0KIUhBTkRfQ09MT1Ig' +
                  'NDYwNzk5DQohSEFORF9DRU5URVJfU0NSRUVOIDMwIDExDQoNCi8vIEZvZyBvZiBX' +
                  'YXINCg0KLy8gR29hbHMNCg0KLy8gQUkNCiFTRVRfQUlfQVVUT19SRVBBSVINCiFT' +
                  'RVRfQUlfQ0hBUkFDVEVSIFNFUkZTX1BFUl8xMF9IT1VTRVMgMTANCiFTRVRfQUlf' +
                  'Q0hBUkFDVEVSIEJVSUxERVJTX0NPVU5UIDEyDQoNCi8vIEFsbGlhbmNlcw0KIVNF' +
                  'VF9BTExJQU5DRSAwIDANCiFTRVRfQUxMSUFOQ0UgMSAxDQohU0VUX0FMTElBTkNF' +
                  'IDMgMQ0KDQovLyBHcmFudC9CbG9jayBob3VzZXMNCiFIT1VTRV9CTE9DSyAyMyAv' +
                  'LyBTaWVnZVdvcmtzaG9wDQohSE9VU0VfQkxPQ0sgMjkgLy8gbWFya2V0cGxhY2UN' +
                  'Cg0KLy8gQmxvY2sgdW5pdHMNCg0KLy8gQmxvY2sgdHJhZGVzDQoNCi8vIEhvdXNl' +
                  'cw0KIVNFVF9IT1VTRSA4IDEyIDYgMCAvLyBmYXJtDQohU0VUX0hPVVNFIDYgMzkg' +
                  'MTEgMSAvLyBmaXNoZXJtYW5zDQohU0VUX0hPVVNFIDggMTcgNiAwIC8vIGZhcm0N' +
                  'CiFTRVRfSE9VU0UgMzIgNiAxMSAwIC8vIGNpZGVyTWFrZXINCiFTRVRfSE9VU0Ug' +
                  'MzIgMTAgMTUgMCAvLyBjaWRlck1ha2VyDQohU0VUX0hPVVNFIDkgMzcgNiAwIC8v' +
                  'IHdvb2RjdXR0ZXJzDQohU0VUX0hPVVNFIDIyIDI0IDMgMCAvLyBtaWxsDQohU0VU' +
                  'X0hPVVNFIDcgMjUgMTEgMSAvLyBiYWtlcnkNCiFTRVRfSE9VU0UgMzMgMzYgMTEg' +
                  'MCAvLyBzYXdtaWxsDQohU0VUX0hPVVNFIDE0IDYgNCAwIC8vIHN0b25lY3V0dGVy' +
                  'cw0KIVNFVF9IT1VTRSAyNyAyNCAxNSAwIC8vIHRhdmVybg0KIVNFVF9IT1VTRSAz' +
                  'NyAzMiA1IDAgLy8gY290dGFnZQ0KDQovLyBSb2FkcyBhbmQgZmllbGRzDQoNCiFT' +
                  'RVRfUk9BRCAyNCAzICFTRVRfUk9BRCA2IDQgIVNFVF9ST0FEIDI0IDQgIVNFVF9S' +
                  'T0FEIDYgNQ0KIVNFVF9ST0FEIDcgNSAhU0VUX1JPQUQgMjQgNSAhU0VUX1JPQUQg' +
                  'MzIgNSAhU0VUX1JPQUQgNyA2DQohU0VUX1JPQUQgMTIgNiAhU0VUX1JPQUQgMTcg' +
                  'NiAhU0VUX1JPQUQgMjQgNiAhU0VUX1JPQUQgMzIgNg0KIVNFVF9ST0FEIDM3IDYg' +
                  'IVNFVF9ST0FEIDcgNyAhU0VUX1JPQUQgMTIgNyAhU0VUX1JPQUQgMTMgNw0KIVNF' +
                  'VF9ST0FEIDE0IDcgIVNFVF9ST0FEIDE1IDcgIVNFVF9ST0FEIDE2IDcgIVNFVF9S' +
                  'T0FEIDE3IDcNCiFTRVRfUk9BRCAyNCA3ICFTRVRfUk9BRCAzMiA3ICFTRVRfUk9B' +
                  'RCAzNyA3ICFTRVRfUk9BRCA3IDgNCiFTRVRfRklFTEQgOSA4IDAgIVNFVF9ST0FE' +
                  'IDEzIDggIVNFVF9GSUVMRCAxNyA4IDAgIVNFVF9ST0FEIDI0IDgNCiFTRVRfUk9B' +
                  'RCAzMiA4ICFTRVRfUk9BRCAzNyA4ICFTRVRfT1JDSEFSRCAxIDkgNiAhU0VUX1JP' +
                  'QUQgNyA5DQohU0VUX0ZJRUxEIDEwIDkgMCAhU0VUX1JPQUQgMTMgOSAhU0VUX0ZJ' +
                  'RUxEIDE2IDkgMCAhU0VUX1JPQUQgMjQgOQ0KIVNFVF9ST0FEIDMyIDkgIVNFVF9S' +
                  'T0FEIDM3IDkgIVNFVF9ST0FEIDcgMTAgIVNFVF9ST0FEIDEzIDEwDQohU0VUX0ZJ' +
                  'RUxEIDE3IDEwIDAgIVNFVF9ST0FEIDI0IDEwICFTRVRfUk9BRCAzMiAxMCAhU0VU' +
                  'X1JPQUQgMzcgMTANCiFTRVRfUk9BRCA2IDExICFTRVRfUk9BRCA3IDExICFTRVRf' +
                  'RklFTEQgOSAxMSAwICFTRVRfRklFTEQgMTIgMTEgMA0KIVNFVF9ST0FEIDEzIDEx' +
                  'ICFTRVRfRklFTEQgMTcgMTEgMCAhU0VUX1JPQUQgMjQgMTEgIVNFVF9ST0FEIDI1' +
                  'IDExDQohU0VUX1JPQUQgMzAgMTEgIVNFVF9ST0FEIDMxIDExICFTRVRfUk9BRCAz' +
                  'MiAxMSAhU0VUX1JPQUQgMzYgMTENCiFTRVRfUk9BRCAzNyAxMSAhU0VUX1JPQUQg' +
                  'MzggMTEgIVNFVF9ST0FEIDM5IDExICFTRVRfT1JDSEFSRCAzIDEyIDYNCiFTRVRf' +
                  'Uk9BRCA2IDEyICFTRVRfUk9BRCA3IDEyICFTRVRfUk9BRCA4IDEyICFTRVRfUk9B' +
                  'RCA5IDEyDQohU0VUX1JPQUQgMTAgMTIgIVNFVF9ST0FEIDExIDEyICFTRVRfUk9B' +
                  'RCAxMiAxMiAhU0VUX1JPQUQgMTMgMTINCiFTRVRfUk9BRCAxNCAxMiAhU0VUX1JP' +
                  'QUQgMTUgMTIgIVNFVF9ST0FEIDE2IDEyICFTRVRfUk9BRCAxNyAxMg0KIVNFVF9S' +
                  'T0FEIDE4IDEyICFTRVRfUk9BRCAxOSAxMiAhU0VUX1JPQUQgMjAgMTIgIVNFVF9S' +
                  'T0FEIDIxIDEyDQohU0VUX1JPQUQgMjIgMTIgIVNFVF9ST0FEIDIzIDEyICFTRVRf' +
                  'Uk9BRCAyNCAxMiAhU0VUX1JPQUQgMjUgMTINCiFTRVRfUk9BRCAyNiAxMiAhU0VU' +
                  'X1JPQUQgMjcgMTIgIVNFVF9ST0FEIDI4IDEyICFTRVRfUk9BRCAyOSAxMg0KIVNF' +
                  'VF9ST0FEIDMwIDEyICFTRVRfUk9BRCAzMSAxMiAhU0VUX1JPQUQgMzIgMTIgIVNF' +
                  'VF9ST0FEIDMzIDEyDQohU0VUX1JPQUQgMzQgMTIgIVNFVF9ST0FEIDM1IDEyICFT' +
                  'RVRfUk9BRCAzNiAxMiAhU0VUX1JPQUQgMzcgMTINCiFTRVRfT1JDSEFSRCAxIDEz' +
                  'IDYgIVNFVF9PUkNIQVJEIDYgMTMgNiAhU0VUX1JPQUQgMTEgMTMgIVNFVF9ST0FE' +
                  'IDI3IDEzDQohU0VUX1JPQUQgMzEgMTMgIVNFVF9ST0FEIDMyIDEzICFTRVRfT1JD' +
                  'SEFSRCA2IDE0IDYgIVNFVF9ST0FEIDExIDE0DQohU0VUX1JPQUQgMjcgMTQgIVNF' +
                  'VF9ST0FEIDMxIDE0ICFTRVRfUk9BRCAzMiAxNCAhU0VUX1JPQUQgMTAgMTUNCiFT' +
                  'RVRfUk9BRCAxMSAxNSAhU0VUX1JPQUQgMjQgMTUgIVNFVF9ST0FEIDI3IDE1ICFT' +
                  'RVRfUk9BRCAzMSAxNQ0KIVNFVF9ST0FEIDMyIDE1ICFTRVRfUk9BRCAxMCAxNiAh' +
                  'U0VUX1JPQUQgMTEgMTYgIVNFVF9ST0FEIDI0IDE2DQohU0VUX1JPQUQgMjUgMTYg' +
                  'IVNFVF9ST0FEIDI2IDE2ICFTRVRfUk9BRCAyNyAxNiAhU0VUX09SQ0hBUkQgNSAx' +
                  'NyA2DQohU0VUX09SQ0hBUkQgMTEgMTcgNg0KDQovLyBGZW5jZXMNCg0KDQotLS0t' +
                  'LUhhbmQzLS0tLS0NCiFIQU5EX0NVUlJFTlQgMw0KIUhBTkRfQUxMT1dfQUkNCiFI' +
                  'QU5EX0FDVElWQVRFDQohSEFORF9BSV9DSEFSQUNURVIgMA0KIUhBTkRfQ09MT1Ig' +
                  'NTQ0NDANCiFIQU5EX0NFTlRFUl9TQ1JFRU4gMzMgMTUNCg0KLy8gRm9nIG9mIFdh' +
                  'cg0KDQovLyBHb2Fscw0KDQovLyBBSQ0KIVNFVF9BSV9BVVRPX1JFUEFJUg0KIVNF' +
                  'VF9BSV9DSEFSQUNURVIgU0VSRlNfUEVSXzEwX0hPVVNFUyAxMA0KIVNFVF9BSV9D' +
                  'SEFSQUNURVIgQlVJTERFUlNfQ09VTlQgMTINCg0KLy8gQWxsaWFuY2VzDQohU0VU' +
                  'X0FMTElBTkNFIDAgMA0KIVNFVF9BTExJQU5DRSAxIDENCiFTRVRfQUxMSUFOQ0Ug' +
                  'MiAxDQoNCi8vIEdyYW50L0Jsb2NrIGhvdXNlcw0KIUhPVVNFX0JMT0NLIDIzIC8v' +
                  'IFNpZWdlV29ya3Nob3ANCiFIT1VTRV9CTE9DSyAyOSAvLyBtYXJrZXRwbGFjZQ0K' +
                  'DQovLyBCbG9jayB1bml0cw0KDQovLyBCbG9jayB0cmFkZXMNCg0KLy8gSG91c2Vz' +
                  'DQohU0VUX0hPVVNFIDExIDMzIDE1IDEgLy8gY2FtcA0KIVdBUkVfT1VUX0FERF9U' +
                  'T19MQVNUIDIgNjAgLy8gc3RvbmUNCiFXQVJFX09VVF9BRERfVE9fTEFTVCAzIDYw' +
                  'IC8vIHdvb2QNCiFXQVJFX09VVF9BRERfVE9fTEFTVCA4IDMwIC8vIGdvbGQNCiFX' +
                  'QVJFX09VVF9BRERfVE9fTEFTVCAyOCA2MCAvLyBmaXNoDQohV0FSRV9PVVRfQURE' +
                  'X1RPX0xBU1QgMjkgNSAvLyBjbHViDQohV0FSRV9PVVRfQUREX1RPX0xBU1QgMzAg' +
                  'NjAgLy8gY2lkZXINCiFTRVRfSE9VU0UgMTMgMzAgMTAgMCAvLyBzY2hvb2wNCg0K' +
                  'Ly8gUm9hZHMgYW5kIGZpZWxkcw0KDQohU0VUX1JPQUQgMzAgMTAgIVNFVF9ST0FE' +
                  'IDMxIDEwICFTRVRfUk9BRCAzMyAxNQ0KDQovLyBGZW5jZXMNCg0KDQotLS0tLUhh' +
                  'bmQ0LS0tLS0NCiFIQU5EX0NVUlJFTlQgNA0KIUhBTkRfTkVVVFJBTF9UWVBFIDAg' +
                  'Ly8gSW5lcnQNCiFIQU5EX0FDVElWQVRFDQoNCi8vIEZvZyBvZiBXYXINCg0KLy8g' +
                  'SG91c2VzDQohU0VUX0hPVVNFIDE3IDI4IDIyIDAgLy8gdG93ZXJfYXJyb3cNCg0K' +
                  'Ly8gUm9hZHMgYW5kIGZpZWxkcw0KDQoNCi8vIEZlbmNlcw0KDQoNCi0tLS0tSGFu' +
                  'ZDUtLS0tLQ0KIUhBTkRfQ1VSUkVOVCA1DQohSEFORF9ORVVUUkFMX1RZUEUgMSAv' +
                  'LyBIb3N0aWxlDQohSEFORF9BQ1RJVkFURQ0KDQovLyBGb2cgb2YgV2FyDQoNCi8v' +
                  'IFJvYWRzIGFuZCBmaWVsZHMNCg0KDQovLyBGZW5jZXMNCg0KDQovLyBUcmlnZ2Vy' +
                  'cw0KIVNFVF9UUklHR0VSIDEgMjMgMzUgMjMgMzgNCiFTRVRfVFJJR0dFUiAyIDI2' +
                  'IDIwIDMxIDIxDQoNCg0KLy8gVGhpcyBtaXNzaW9uIHdhcyBtYWRlIHdpdGggTWFw' +
                  'IEVkaXRvciBvZiAiS25pZ2h0cyBQcm92aW5jZS4gQWxwaGEgMTEuMSByOTA2NCAo' +
                  'MjAyMC0wNi0yNyAxMDo0OCkiICBvbiAxNS03LTIwMjAgMDk6Mjk6NTgNCg==';
begin
	TestString(FormatDateTime('yyyy/mm/dd hh:nn:ss.zzz', Now), $1a2b3c4d);
	TestString('AcrossDesert', $1a2b3c4d);
	TestString(BASIC_MAP_DAT, $1a2b3c4d);
end;

procedure TMurMurVsTests.SetUp;
begin
	if not QueryPerformanceFrequency(fFreq) then
		fFreq := -1;
end;

procedure TMurMurVsTests.TearDown;
begin
end;

initialization
  TDUnitX.RegisterTestFixture(TMurMurVsTests);

end.
