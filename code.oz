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

      fun {NtsNotes Nts}
         case Nts of nil then nil
         [] H|T then {NoteToExtended H}|{NtsNotes T}
         end
      end
      NoteNames = [c c#4 d d#4 e f f#4 g g#4 a a#4 b]
      Notes = {NtsNotes NoteNames}

      fun {ChangeDuration Note Factor}
         case Note of nil then nil
         [] H|T then
            note(name: H.name
                 octave: H.octave
                 sharp: H.sharp
                 duration: (H.duration * Factor)
                 instrument: H.instrument)|{ChangeDuration T Factor}
         else
            note(name: Note.name
            octave: Note.octave
            sharp: Note.sharp
            duration: (Note.duration * Factor)
            instrument: Note.instrument)
         end
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
      {Filt {Flatten {P2T Partition.1}}}
   end

   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

   fun {Mix P2T Music}
      
      fun {GetHeight Note}
         fun {NtsNotes Nts}
            case Nts of nil then nil
            [] H|T then {NoteToExtended H}|{NtsNotes T}
            end
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
         if {IsList Note} then
            if I >= Note.1.duration*(44100.0) - 1.0 then nil|0.0|nil
            else
               ChordList := 0.0
               for E in Note do
                  if (E.name == silence) then
                     skip
                  else
                     ChordList := (0.5*{Float.sin 2.0*3.1415926535*{Frequence E}*I/44100.0}) + @ChordList
                  end
               end
               @ChordList/{IntToFloat {Length Note}}|{NoteToSample Note I+1.0}
            end
         else
            if Note.name == silence then 0.0
            else
               if I >= Note.duration*44100.0 - 1.0 then nil|0.0|nil
               else
                  (0.5*{Float.sin 2.0*3.1415926535*{Frequence Note}*I/44100.0})|{NoteToSample Note I+1.0}
               end
            end
         end
      end
      fun {ExtendedToSample Ext}
         case Ext of nil then nil
         [] H|T then {NoteToSample H 0.0}|{ExtendedToSample T}
         else
            {NoteToSample Ext 0.0}
         end
      end

      fun {Wave FileName}
         {Project.readFile FileName.1}
      end

      fun {Merge Musics}
         fun {MSample Ms}
            case Ms of nil then nil
            [] H|T then 
               case H
               of I#M then I#{Mixer M}|{MSample T}
               end
            end
         end
         SampleMusics = {MSample Musics.1}
         fun {MergeSamples Ms}
            AllNil = {NewCell true}
            SumM = {NewCell 0.0}
            fun {NextSamples Mxs}
               case Mxs of nil then nil
               [] H|T then
                  case H
                  of I#W then I#W.1.2|{NextSamples T}
                  end
               end
            end
            Nxt = {NextSamples Ms}
         in
            for E in Ms do
               case E of I#V then
                  if V.1.1 == nil then
                     skip
                  else
                     AllNil := false
                  end
               end
            end

            if @AllNil  then nil
            else
               for E in Ms do
                  case E of I#V then
                     if V.1.1 == nil then
                        skip
                     else
                        SumM := @SumM + V.1.1*I
                     end
                  end
               end
               @SumM|{MergeSamples Nxt}
            end
         end
      in
         {MergeSamples SampleMusics}
      end
      
      fun {ToSample Part}
         case {Label Part}
         of samples then Part
         [] partition then {Flatten {ExtendedToSample {P2T Part}}}
         [] wave then {Flatten {Wave Part}}
         [] merge then {Merge Part}
         %else {Filter Part}
         end
      end

      fun {Mixer M}
         case M of nil then nil
         [] H|T then {ToSample H}|{Mixer T}
         else {ToSample Music}
         end
      end
   in
      {Flatten {Mixer [merge([0.1#Music 0.9#[wave('wave/animals/cow.wav')]])]}}
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
   {Browse {Mix PartitionToTimedList Music}}
   %{Browse {Project.run Mix PartitionToTimedList Music 'out.wav'}}
   
   % Shows the total time to run your code.
   {Browse {IntToFloat {Time}-Start} / 1000.0}
end
