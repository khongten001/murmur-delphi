program MurMur_Delphi;
{$APPTYPE CONSOLE}
{$R *.res}
uses
  SysUtils,
  MurmurHash in 'MurmurHash.pas';

const
  someText = 'Just some text';
  someOtherText = 'Just some Other text';

begin
  try
    { TODO -oUser -cConsole Main : Insert code here }
    WriteLn(
      'TMurMur1.Hash (1) of "' + someText + '" = ' +
      IntToStr(TMurMur1.Hash(
        PAnsiChar(someText)^, Length(someText) * SizeOf(AnsiChar), 0
      ))
    );
    WriteLn(
      'TMurMur1.Hash (2) of "' + someText + '" = ' +
      IntToStr(TMurMur1.Hash(
        PAnsiChar(someText)^, Length(someText) * SizeOf(AnsiChar), 0
      ))
    );
    WriteLn(
      'TMurMur1.Hash (3) of "' + someText + '" = ' +
      IntToStr(TMurMur1.Hash(
        PAnsiChar(someText)^, Length(someText) * SizeOf(AnsiChar), 0
      ))
    );

    WriteLn;

    WriteLn(
      'TMurMur1.Hash (4) of "' + someOtherText + '" = ' +
      IntToStr(TMurMur1.Hash(
        PAnsiChar(someOtherText)^, Length(someOtherText) * SizeOf(AnsiChar), 0
      ))
    );
    WriteLn(
      'TMurMur1.Hash (5) of "' + someOtherText + '" = ' +
      IntToStr(TMurMur1.Hash(
        PAnsiChar(someOtherText)^, Length(someOtherText) * SizeOf(AnsiChar), 0
      ))
    );
    WriteLn(
      'TMurMur1.Hash (6) of "' + someOtherText + '" = ' +
      IntToStr(TMurMur1.Hash(
        PAnsiChar(someOtherText)^, Length(someOtherText) * SizeOf(AnsiChar), 0
      ))
    );

    WriteLn;
    WriteLn;

    WriteLn(
      'TMurMur1.HashAligned (1) of "' + someText + '" = ' +
      IntToStr(TMurMur1.HashAligned(
        PAnsiChar(someText)^, Length(someText) * SizeOf(AnsiChar), 0
      ))
    );
    WriteLn(
      'TMurMur1.HashAligned (2) of "' + someText + '" = ' +
      IntToStr(TMurMur1.HashAligned(
        PAnsiChar(someText)^, Length(someText) * SizeOf(AnsiChar), 0
      ))
    );
    WriteLn(
      'TMurMur1.HashAligned (3) of "' + someText + '" = ' +
      IntToStr(TMurMur1.HashAligned(
        PAnsiChar(someText)^, Length(someText) * SizeOf(AnsiChar), 0
      ))
    );

    WriteLn;

    WriteLn(
      'TMurMur1.HashAligned (4) of "' + someOtherText + '" = ' +
      IntToStr(TMurMur1.HashAligned(
        PAnsiChar(someOtherText)^, Length(someOtherText) * SizeOf(AnsiChar), 0
      ))
    );
    WriteLn(
      'TMurMur1.HashAligned (5) of "' + someOtherText + '" = ' +
      IntToStr(TMurMur1.HashAligned(
        PAnsiChar(someOtherText)^, Length(someOtherText) * SizeOf(AnsiChar), 0
      ))
    );
    WriteLn(
      'TMurMur1.HashAligned (6) of "' + someOtherText + '" = ' +
      IntToStr(TMurMur1.HashAligned(
        PAnsiChar(someOtherText)^, Length(someOtherText) * SizeOf(AnsiChar), 0
      ))
    );
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
