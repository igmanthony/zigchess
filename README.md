# zigchess

This is a bare-bones move calculation program written in Zig. It draws heavy inspiration from a few Rust-based chess engines (mostly [shakmaty](https://github.com/niklasf/shakmaty) and [rustic](https://github.com/mvanthoor/rustic)). The "magic.zig", "setup.zig", and "attack.zig" files were mostly translations of the shakmaty project as I don't understand magic bitboards very well.

As both of these chess engines were GPL-3 licensed, this program likely qualifies as a derivative work (Date 2/17/2021) and is licensed under the GPL3. I don't personally care for the GPL3 License, so if I'm understanding the GPL3 wrong, feel free to contact me to correct me and I'll license what I can it under the MIT.

No external libraries were used for this program. The only parts of the standard zig library that are imported are for tests and print-debugging and could be omitted. One or two functions were copied and modified from the Zig standard library (I think some of the MoveList append/pop/push).

Right now this program doesn't do much except calculate moves. It's almost perfect but there are still 1 or two small bugs at larger perft depths on unusual positions (see the perfts.zig file) that I haven't figured out (perft 8 on the standard position works fine).

This engine gives comparable results to the shakmaty engine (~300 ms for perft 6 and ~15 s for perft 7 from the starting chess position on a reasonably-good i7-based computer). The binary produced using Zig v. 7.1(ish) with -Drelease-fast is 140 kb in size!
