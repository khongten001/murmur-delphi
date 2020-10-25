# murmur-delphi
Murmur hash for Delphi

MurmurHash is a fast, non-cryptographic, hash, suitable for hash tables.

It comes in multiple variants:

- hash result of 32 bits
- hash result of 64 bits
- hash result of 128 bits, optimized for x86 architecture
- hash result of 128 bits, optimized for x64 architecture


Sample Usage
----------------

MurMur supports any other kind of data:

    var
      hash:    Cardinal;
      hash128: string;
      find:    WIN32_FIND_DATA;
      find2:   string;
    
    hash := TMurmur3.Hash_x86_32(find, SizeOf(WIN32_FIND_DATA), $ba5eba11);
    hash := TMurmur3.Hash_x86_32(Pointer(find2)^, Length(find2) * SizeOf(Char), 123);
    // These are CPU target optimized
    hash := TMurmur3.Hash(find, SizeOf(WIN32_FIND_DATA), $ba5eba11);
    hash := TMurmur3.Hash(Pointer(find2)^, Length(find2) * SizeOf(Char), 123);

Test Setting
----------------
    Input:  9084 ANSI characters from a Base64 encoded text (Found in MurMurHashVsTests.pas Ln: 260)
    CPU:    Intel Core I5-8600K @ 4.2 GHz
    Memory: 32GB DDR3 @ 2666 MHz in Dual-Channel

Test Results
----------------

x86 build results:

    MurMur1.Hash > Hashed 1000x in 20.870 µs average
    
    MurMur2.Hash > Hashed 1000x in 17.359 µs average
    
    MurMur2.HashA > Hashed 1000x in 17.457 µs average
    
    MurMur2.Hash64A > Hashed 1000x in 26.224 µs average
    
    MurMur2.Hash64B > Hashed 1000x in 15.320 µs average
    
    MurMur3.Hash > Hashed 1000x in 17.995 µs average
    
    Adler32CRC > Hashed 1000x in 31.032 µs average
    
    BobJenkins > Hashed 1000x in 24.993 µs average

x64 build results:

    MurMur1.Hash > Hashed 1000x in 20.167 µs average
    
    MurMur2.Hash > Hashed 1000x in 18.292 µs average
    
    MurMur2.HashA > Hashed 1000x in 18.282 µs average
    
    MurMur2.Hash64A > Hashed 1000x in 9.585 µs average
    
    MurMur2.Hash64B > Hashed 1000x in 15.067 µs average
    
    MurMur3.Hash > Hashed 1000x in 9.887 µs average
    
    Adler32CRC > Hashed 1000x in 30.083 µs average
    
    BobJenkins > Hashed 1000x in 24.766 µs average
