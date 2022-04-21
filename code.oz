local
   % See project statement for API details.
   [Project] = {Link ['Project2022.ozf']}
   Time = {Link ['x-oz://boot/Time']}.1.getReferenceTime

   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

   % Translate a note to the extended notation.
   fun {NoteToExtended Note}
      case Note
      of Name#Octave then
         note(name:Name octave:Octave sharp:true duration:1.0 instrument:none)
      [] Atom then
         case {AtomToString Atom}
         of [_] then
            note(name:Atom octave:4 sharp:false duration:1.0 instrument:none)
         [] [N O] then
            note(name:{StringToAtom [N]}
                 octave:{StringToInt [O]}
                 sharp:false
                 duration:1.0
                 instrument: none)
         end
      end
   end

   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

   fun {PartitionToTimedList Partition}
      fun {Reverser M Acc}
         case M
         of nil then Acc
         [] H|T then
            {Reverser T H|Acc}
         else
            M
         end
      end

      fun {NtsNotes Nts}
         fun {NtsNotesAcc Nts Acc}
            case Nts of nil then Acc
            [] H|T then {NtsNotesAcc T {NoteToExtended H}|Acc}
            end
         end
      in
         {Reverser {NtsNotesAcc Nts nil} nil}
      end

      NoteNames = [c c#4 d d#4 e f f#4 g g#4 a a#4 b]
      Notes = {NtsNotes NoteNames}

      fun {ChangeDuration Note Factor}
         fun {ChangeDurationAcc Note Factor Acc}
            case Note of nil then Acc
            [] H|T then
               {ChangeDurationAcc T Factor note(name: H.name
                                             octave: H.octave
                                             sharp: H.sharp
                                             duration: (H.duration * Factor)
                                             instrument: H.instrument)|Acc}
            else
               note(name: Note.name
               octave: Note.octave
               sharp: Note.sharp
               duration: (Note.duration * Factor)
               instrument: Note.instrument)
            end
         end
      in
         {Reverser {ChangeDurationAcc Note Factor nil} nil}
      end

      fun {Stretch NC Factor}
         X
         CD
      in
         case NC
         of nil then nil
         [] H|T then
            X = {Flat H}
            case {Label X} of chord then
               CD = chord({ChangeDuration X.1 Factor})
            else
               CD = {ChangeDuration X Factor}
            end
            CD|{Stretch T Factor}
         else
            X = {Flat NC}
            case {Label X} of chord then
               CD = chord({ChangeDuration X.1 Factor})
            else
               CD = {ChangeDuration X Factor}
            end
            CD
         end
      end

      fun {Sum L Acc}
         case L of nil then Acc
         [] H|T then 
            case {Label H} of chord then 
               {Sum T Acc+H.1.1.duration}
            else
               {Sum T Acc+H.duration}
            end
         end
      end

      fun {Dur PartIt Sec}
         {Stretch PartIt Sec/{Sum PartIt 0.0}}
      end

      fun {Drone NC Amount}
         RetRev
         Ret
      in
         RetRev = {NewCell nil}
         Ret = {NewCell nil}
         for I in 1..Amount do
            for E in NC do
               RetRev := {Flat E}|@RetRev
            end
         end
         for E in @RetRev do
            Ret := E|@Ret
         end
         @Ret
      end

      fun {Transpose NC Num}
         S = {Length Notes}
         fun {FindInd Nts N Acc}
            EN
         in
            case Nts of nil then ~1
            [] H|T then
               EN = {Flat N}
               if H.name == EN.name then 
                  if (H.sharp == EN.sharp) then
                     Acc
                  else
                     {FindInd T N Acc+1}
                  end
               else {FindInd T N Acc+1}
               end
            end
         end
         fun {GetInd Nts C}
            case Nts of nil then ~1
            [] H|T then
               if C == 0 then H
               else {GetInd T C-1}
               end
            end
         end
         C
         Sm
         El
         fun {NewNote NC Num Dure Instrument}
            Sm = ({FindInd Notes NC 0} + Num)
            if Num < 0 then
               C = S + Sm mod S
            else
               C = Sm mod S
            end
            El = {GetInd Notes C}
            note(name: El.name
            octave: (El.octave+(Sm div S))
            sharp: El.sharp
            duration: Dure
            instrument: Instrument)
         end
      in
         case NC of nil then nil
         [] H|T then {NewNote H Num H.duration H.instrument}|{Transpose T Num}
         else {NewNote NC Num NC.duration NC.instrument}
         end
      end

      fun {Transposer NC Num}
         FlatNC
      in
         case NC of nil then nil
         [] H|T then 
            FlatNC = {Flat H}
            {Transpose FlatNC.1 Num}|{Transposer T Num}
         end
      end

      fun {ChordToExtended Chord}
         case Chord of nil then nil
         [] H|T then {Flat H}|{ChordToExtended T}
         end
      end

      Chorder = {NewCell 0}

      fun {ConvertExtended PartIt}
         if {IsList PartIt} then
            Chorder := chord({ChordToExtended PartIt})
            @Chorder
         else
            case {Label PartIt} 
            of note then PartIt
            [] chord then PartIt
            [] stretch then {Stretch {P2T PartIt.1} PartIt.factor}
            [] duration then {Dur {Flatten {NFilt PartIt}} PartIt.seconds} 
            [] drone then {Drone {P2T PartIt.1} PartIt.amount}
            [] transpose then {Transposer {P2T PartIt.1} PartIt.semitones}
            else {NoteToExtended PartIt}
            end
         end
      end

      fun {Flat PartItem}
         {ConvertExtended PartItem}
      end

      fun {Filt NC}
         case NC of nil then nil
         [] H|T then 
            case {Label H} of chord
            then H.1|{Filt T}
            else H|{Filt T}
            end
         else
            NC
         end
      end

      fun {P2T Part}
         case Part of nil then nil
         [] H|T then {Flat H}|{P2T T}
         else {Flat Part}
         end
      end

      fun {NFilt Part}
         {Flatten {P2T Part.1}}
      end
   in
      case Partition
      of partition(X) then {Filt {Flatten {P2T X}}}
      else nil
      end
   end

   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

   fun {Mix P2T Music}
      fun {Reverser Music Acc}
         case Music
         of nil then Acc
         [] H|T then
            {Reverser T H|Acc}
         end
      end

      fun {GetHeight Note}
         fun {NtsNotes Nts}
            fun {NtsNotesAcc Nts Acc}
               case Nts of nil then Acc
               [] H|T then {NtsNotesAcc T {NoteToExtended H}|Acc}
               end
            end
         in
            {Reverser {NtsNotesAcc Nts nil} nil}
         end
         NoteNames = [c c#4 d d#4 e f f#4 g g#4 a a#4 b]
         Notes= {NtsNotes NoteNames}
         fun {FindInd Nts N Acc}
            case Nts of nil then ~1
            [] H|T then
               if H.name == N.name then 
                  if (H.sharp == N.sharp) then
                     Acc
                  else
                     {FindInd T N Acc+1}
                  end
               else {FindInd T N Acc+1}
               end
            end
         end
      in
         {FindInd Notes Note 0} - 9 + (Note.octave - 4)*{Length Notes}
      end

      fun {Frequence Note}
         {Pow 2.0 {IntToFloat {GetHeight Note}}/12.0} * 440.0
      end

      ChordList = {NewCell 0.0}

      fun {NoteToSample Note I}
         fun {NoteToSampleAcc Note I Acc}
            if {IsList Note} then
               if I >= Note.1.duration*(44100.0) - 1.0 then Acc
               else
                  ChordList := 0.0
                  for E in Note do
                     if (E.name == silence) then
                        skip
                     else
                        ChordList := (0.5*{Float.sin 2.0*3.1415926535*{Frequence E}*I/44100.0}) + @ChordList
                     end
                  end
                  {NoteToSampleAcc Note I+1.0 @ChordList/{IntToFloat {Length Note}}|Acc}
               end
            else
               if Note.name == silence then 0.0
               else
                  if I >= Note.duration*44100.0 - 1.0 then Acc
                  else
                     {NoteToSampleAcc Note I+1.0 (0.5*{Float.sin 2.0*3.1415926535*{Frequence Note}*I/44100.0})|Acc}
                  end
               end
            end
         end
      in
         {Reverser {NoteToSampleAcc Note I nil} nil}
      end

      fun {ExtendedToSample Ext}
         fun {ExtendedToSampleAcc Ext Acc}
            case Ext of nil then Acc
            [] H|T then {ExtendedToSampleAcc T {NoteToSample H 0.0}|Acc}
            else
               {NoteToSample Ext 0.0}
            end
         end
      in
         {Reverser {ExtendedToSampleAcc Ext nil} nil}
      end

      fun {Wave FileName}
         {Project.readFile FileName}
      end

      fun {Merge Musics}
         fun {MSample Ms Acc}
            case Ms of nil then Acc
            [] H|T then 
               case H
               of I#M then {MSample T I#{Mixer M}.1|Acc}
               end
            end
         end
         SampleMusics = {Reverser {MSample Musics nil} nil}
         fun {MergeSamples Ms Acc}
            AllNil = {NewCell true}
            SumM = {NewCell 0.0}
            fun {NextSamples Mxs Acc}
               case Mxs of nil then Acc
               [] H|T then
                  case H
                  of I#W then
                     case W of nil then {NextSamples T I#W|Acc}
                     else
                        {NextSamples T I#W.2|Acc}
                     end
                  end
               end
            end
            Nxt = {Reverser {NextSamples Ms nil} nil}
         in
            for E in Ms do
               case E of I#V then
                  case V of nil then skip
                  else
                     AllNil := false
                  end
               end
            end

            if @AllNil then Acc
            else
               for E in Ms do
                  case E of I#V then
                     case V of nil then skip
                     else
                        SumM := @SumM + V.1*I
                     end
                  end
               end
               {MergeSamples Nxt @SumM|Acc}
            end 
         end
      in
         {Reverser {MergeSamples SampleMusics nil} nil}
      end

      fun {Reverse Music}
         {Reverser {Mixer Music}.1 nil}
      end

      fun {RepeatAcc N Music Acc}
         if N=<0 then
            Acc
         else
            {RepeatAcc N-1 Music Music|Acc}
         end
      end

      fun {Repeat N Music}
         {Flatten {RepeatAcc N {Mixer Music}.1 nil}}
      end
      
      fun {Loop Duration Music}
         fun {GetPart X M Acc}
            if X =< 0.0 then Acc
            else
               case M of nil then Acc
               [] H|T then {GetPart X-1.0 T H|Acc}
               end
            end
         end
         M = {Mixer Music}.1
         N = ({FloatToInt Duration*44100.0} div {Length M})
         D = (Duration*44100.0 / {IntToFloat {Length M}}) - {IntToFloat N}
      in
         {Flatten {RepeatAcc N M nil}|{Reverser {GetPart {IntToFloat {Length M}}*D M nil} nil}}
      end

      /*
      fun {Clip Low High Music}
         skip
      end

      fun {Echo Delay Decay Music}
         skip
      end

      fun {Fade In Out Music}
         skip
      end
      */
      fun {Cut Start End Music}
         fun {StartCut Start Music}
            if Start=<0.0 then Music
            else
               case Music of nil then 0.0
               [] H|T then {StartCut Start-1.0 T}
               else 0.0
               end
            end
         end

         fun {EndCut End Music Acc}
            if End=<0.0 then Acc
            else
               case Music of nil then {EndCut End-1.0 Music 0.0|Acc}
               [] H|T then {EndCut End-1.0 T H|Acc}
               else {EndCut End-1.0 Music 0.0|Acc}
               end
            end
         end
         M = {Mixer Music}.1
      in
         {Reverser {Flatten {EndCut ((End-Start)*44100.0) {StartCut (Start*44100.0) M} nil}} nil}
      end
      

      fun {ToSample Part}
         case Part
         of samples(X) then X
         [] partition(X) then {Flatten {ExtendedToSample {P2T partition(X)}}}
         [] wave(X) then {Flatten {Wave X}}
         [] merge(X) then {Merge X}
         [] reverse(X) then {Reverse X}
         [] repeat(amount:Y X) then {Repeat Y X}
         [] loop(seconds:Y X) then {Loop Y X}
         [] cut(start:Y1 finish:Y2 X) then {Cut Y1 Y2 X}
         else
            Part
         end
      end

      fun {Mixer M}
         fun {Mixe M Acc}
            case M of nil then Acc
            [] H|T then {Mixe T {ToSample H}|Acc}
            else {ToSample M}
            end
         end
      in
         {Reverser {Mixe M nil} nil}
      end
   in
      {Flatten {Mixer [loop([merge([0.1#Music 0.9#[wave('wave/animals/cow.wav')]])] seconds:37.0)]}}
      %{Flatten {Mixer [wave('wave/animals/cow.wav')]}}
   end

   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

   Music = {Project.load 'joy.dj.oz'}
   Start

   % Uncomment next line to insert your tests.
   % \insert '/full/absolute/path/to/your/tests.oz'
   % !!! Remove this before submitting.
in
   Start = {Time}

   % Uncomment next line to run your tests.
   % {Test Mix PartitionToTimedList}

   % Add variables to this list to avoid "local variable used only once"
   % warnings.
   {ForAll [NoteToExtended Music] Wait}
   
   % Calls your code, prints the result and outputs the result to `out.wav`.
   % You don't need to modify this.
   %{Browse Music}
   %{Browse {Flatten [1 [[2 3] 1] 4 5]}}
   %{Browse {Mix PartitionToTimedList Music}}
   {Browse {Project.run Mix PartitionToTimedList Music 'out.wav'}}
   
   % Shows the total time to run your code.
   {Browse {IntToFloat {Time}-Start} / 1000.0}
end
