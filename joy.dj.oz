% Ode To Joy
local
   Tune = [b b c5 d5 d5 c5 b a g g a b]
   End1 = [stretch(factor:1.5 [b]) stretch(factor:0.5 [a]) stretch(factor:2.0 [a])]
   End2 = [stretch(factor:1.5 [a]) stretch(factor:0.5 [g]) stretch(factor:2.0 [g])]
   Interlude = [a a b g a stretch(factor:0.5 [b c5])
                    b g a stretch(factor:0.5 [b c5])
                b a g a stretch(factor:2.0 [d stretch(factor:0.5 a)]) ]

   % This is not a music.
   %Partition = {Flatten [Tune End2 Interlude Tune End2]}
   Partition = [[b b c5] drone(a4 amount:5) duration( {Flatten [drone([a4 b5] amount:3) Tune End1 Tune End2 [Interlude Tune] End2]} seconds:20.0)]
in
   % This is a music :)
   [partition(Partition)]
end