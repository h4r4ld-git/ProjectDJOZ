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
      in
         case NC
         of nil then nil
         [] H|T then
            X = {Flat H}
            {ChangeDuration X Factor}|{Stretch T Factor}
         else
            X = {Flat NC}
            {ChangeDuration X Factor}
         end
      end

      fun {Sum L Acc}
         case L of nil then Acc
         [] H|T then {Sum T Acc+H.duration}
         end
      end

      fun {Dur PartIt}
         {Stretch PartIt.1 (PartIt.seconds / {Sum {Flat PartIt.1} 0.0})}
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

      fun {ConvertExtended PartIt}
         if {IsList PartIt} then
            {ChordToExtended PartIt}
         else
            case {Label PartIt} 
            of note then PartIt
            [] stretch then {Stretch PartIt.1 PartIt.factor}
            [] duration then {Dur PartIt}
            [] drone then {Drone PartIt.1 PartIt.amount}
            [] transpose then {Transposer PartIt.1 PartIt.semitones}
            else {NoteToExtended PartIt}
            end
         end
      end

      fun {Flat PartItem}
         {ConvertExtended PartItem}
      end

      fun {P2T Part}
         case Part of nil then nil
         [] H|T then {Flat H}|{P2T T}
         end
      end
   in
      if {Label Partition.1} == partition then
         {P2T Partition.1.1}
      else nil
      end
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
         {FindInd Notes Note 0} - 5
      end

      fun {Frequence Note}
         {Pow  2.0 {GetHeight Note}/12.0} * 440.0
      end
       
      fun {NoteToSample Note I Acc}
        if I == Note.duration*44100 then Acc/I
        else
          {NoteToSample Note I+1 (0.5*{Float.sin 2.0*3.1415926535*{Frequence Note}*I/44100.0})+Acc}
        end
      end

      fun {ChordToSample Chord Acc}
         case Chord
         of nil then Acc
         [] H|T then 
            {ChordToSample T {NoteToSample H 0 0.0}|Acc}
         end
      end

      fun {ExtendedToSample Ext}
         case Ext 
         of H|T then {ChordToSample Ext nil}
         [] H then 
            {NoteToSample Ext 0.0 0.0}
         end
      end

      fun {Wave FileName}
         {Project.load FileName}
      end

      %fun {Merge Mwi} body end

      fun {ToSample Part}
         case {Label Part}
         of samples then Part
         [] partition then {ExtendedToSample {P2T Part}}
         [] wave then {Wave FileName}
         %[] merge then {Merge Mwi}
         %else {Filter Part}
         end
      end  
      
      in
         
      end
      {Project.readFile 'wave/animals/cow.wav'}
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
   %{Browse (8+(~12 mod 8))}
   {Browse {PartitionToTimedList Music}}
   {Browse {Project.run Mix PartitionToTimedList Music 'out.wav'}}
   
   % Shows the total time to run your code.
   {Browse {IntToFloat {Time}-Start} / 1000.0}
end
