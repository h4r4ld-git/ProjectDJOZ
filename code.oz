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
      [] silence then
         silence(duration:1.0)
      [] silence(duration:X) then
         silence(duration:X)
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

   % Fonction pour inverser les listes
   fun {Reverser M Acc}
      case M
      of nil then Acc
      [] H|T then
         {Reverser T H|Acc}
      else
         M
      end
   end

   % Transformation de liste de notes en ExtendedNote
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
   Notes = {NtsNotes NoteNames} % Transformer l'ensemble des notes en ExtendedNotes (avec octaves de 4)

   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

   fun {PartitionToTimedList Partition}

      % Fonction pour modifier la durée de la note par un facteur
      fun {ChangeDuration Note Factor}
         fun {ChangeDurationAcc Note Factor Acc}
            case Note of nil then Acc  % Modifier une liste dans le case d'une liste
            [] H|T then
               case {Label H}
               of silence then
                  {ChangeDurationAcc T Factor silence(duration: (H.duration * Factor))|Acc}   
               [] note then
                  {ChangeDurationAcc T Factor note(name: H.name
                                                   octave: H.octave
                                                   sharp: H.sharp
                                                   duration: (H.duration * Factor)
                                                   instrument: H.instrument)|Acc}
               end
            else % Modifier une seule note
               case {Label Note}
               of note then
                  note(name: Note.name
                  octave: Note.octave
                  sharp: Note.sharp
                  duration: (Note.duration * Factor)
                  instrument: Note.instrument)
               [] silence then
                  silence(duration: (Note.duration * Factor))
               end
            end
         end
      in
         {Reverser {ChangeDurationAcc Note Factor nil} nil}
      end

      % Fonction pour modifier La durée d'une partition
      fun {Stretch NC Factor}
         fun {StretchAcc NC Factor Acc}
            X % Element initial
            CD % Liste ou note modifiée
         in
            case NC
            of nil then Acc
            [] H|T then % Cas d'une liste
               X = {ConvertExtended H}
               % Dans le case d'un accord récuperer la durée du premier element de l'accord (tout les elements ont la meme durée)
               case {Label X} of chord then
                  CD = chord({ChangeDuration X.1 Factor})
               else
                  CD = {ChangeDuration X Factor}
               end
               {StretchAcc T Factor CD|Acc}
            else % Cas d'une note
               X = {ConvertExtended NC}
               % Dans le case d'un accord récuperer la durée du premier element de l'accord (tout les elements ont la meme durée)
               case {Label X} of chord then
                  CD = chord({ChangeDuration X.1 Factor})
               else
                  CD = {ChangeDuration X Factor}
               end
               CD
            end
         end
      in
         {Reverser {StretchAcc NC Factor nil} nil}
      end
      % Fonction pour obtenir la somme des durées d'un ensemble de notes (Extended)
      fun {Sum L Acc}
         case L of nil then Acc
         [] H|T then 
            % Dans le cas d'un accord récuperer la durée de la premiere note (car se joue en meme temps)
            case {Label H} of chord then 
               {Sum T Acc+H.1.1.duration}
            else
               {Sum T Acc+H.duration}
            end
         end
      end
      % Fonction pour modifier la durée totale d'une partition
      fun {Dur PartIt Sec}
         % Multiplier chaque durée par Sec/Sum
         {Stretch PartIt Sec/{Sum PartIt 0.0}}
      end
      % Repeter la note ou l'accord
      fun {Drone PartIt Amount}
         Ret % Liste des notes ou accords
         NC = {NFilt [[PartIt.1]]} % Transformer l'element de drone en partition
      in
         Ret = {NewCell nil}
         % Le contenu de drone fois Ammount
         for I in 0..Amount do
            for E in NC do
               Ret := {ConvertExtended E}|@Ret
            end
         end
         @Ret
      end
      % Transposer la note ou les notes
      fun {Transpose NC Num}
         S = {Length Notes} % Nombre de note de base
         % Fonction interne pour trouver l'indice de la note dans les notes de base
         fun {FindInd Nts N Acc}
            EN % Note vers Extended Note
         in
            case Nts of nil then ~1
            [] H|T then
               EN = {ConvertExtended N}
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
         % Obtenir la note sur l'indice C
         fun {GetInd Nts C}
            case Nts of nil then ~1
            [] H|T then
               if C == 0 then H
               else {GetInd T C-1}
               end
            end
         end
         % Faire la transposé de la note
         fun {NewNote NC Num Dure Instrument}
            C % Nouvelle indice de la note transposée dans le tebleau Notes
            Sm % Nouvelle indice de la note transposée
            El % La note transposée
         in
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
         [] H|T then 
            if {Label H} == silence then silence|{Transpose T Num}
            else
               if {Label H} == chord then chord({Transpose H.1 Num})|{Transpose T Num}
               else
                  {NewNote H Num H.duration H.instrument}|{Transpose T Num}
               end
            end
         else
            if {Label NC} == silence then 
               silence
            else
               if {Label NC} == chord then {Transpose NC Num}
               else
                  {NewNote NC Num NC.duration NC.instrument}
               end
            end
         end
      end
      % Transformer les elements d'un accord en Extended Notes
      fun {ChordToExtended Chord}
         case Chord of nil then nil
         [] H|T then {ConvertExtended H}|{ChordToExtended T}
         end
      end

      Chorder = {NewCell 0} % Accord
      % Decoder un element d'une partition
      fun {ConvertExtended PartIt}
         if {IsList PartIt} then % En cas de liste transformer en chord(List) pour garder l'accord avec les operations de Flatten
            Chorder := chord({ChordToExtended PartIt})
            @Chorder
         else
            case {Label PartIt} 
            of note then PartIt
            [] chord then PartIt
            [] stretch then {Stretch {NFilt PartIt} PartIt.factor}
            [] duration then {Dur {NFilt PartIt} PartIt.seconds} 
            [] drone then {Drone PartIt PartIt.amount}
            [] transpose then {Transpose {NFilt PartIt} PartIt.semitones}
            else {NoteToExtended PartIt}
            end
         end
      end
      % Transformer les chord(List) en List
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
      % Filt sans modifier les chord
      fun {NFilt Part}
         {Flatten {P2T Part.1}}
      end
      % Decoder une partition
      fun {P2T Part}
         case Part of nil then nil
         [] H|T then {ConvertExtended H}|{P2T T}
         else {ConvertExtended Part}
         end
      end
      % Decoder une partition
      fun {PartitionToTimedListAcc Partition Acc}
         case Partition of nil then {Filt {Flatten {Reverser Acc nil}}}
         [] H|T then
            case H
            of partition(X) then {PartitionToTimedListAcc T {P2T X}|Acc}
            else nil
            end
         else
            case Partition
            of partition(X) then {Filt {Flatten {P2T X}}}
            else nil
            end
         end
      end
   in
      {PartitionToTimedListAcc Partition nil}
   end

   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

   fun {Mix P2T Music}
      % La hauteur d'une note pour calculer la fréquence
      fun {GetHeight Note}
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
      % La frequence d'une note en appliquant la formule generale
      fun {Frequence Note}
         {Pow 2.0 {IntToFloat {GetHeight Note}}/12.0} * 440.0
      end

      ChordList = {NewCell 0.0}
      % Transformer une note en frequence
      fun {NoteToSample Note I}
         fun {NoteToSampleAcc Note I Acc}
            if {IsList Note} then % cas d'une liste de notes
               if I >= Note.1.duration*(44100.0) - 1.0 then Acc % Terminer lorsque la durée est atteinte
               else
                  ChordList := 0.0
                  % Faire la somme des frequences de la liste des notes
                  for E in Note do
                     if ({Label E} == silence) then
                        skip
                     else
                        ChordList := (0.5*{Float.sin 2.0*3.1415926535*{Frequence E}*I/44100.0}) + @ChordList
                     end
                  end
                  {NoteToSampleAcc Note I+1.0 @ChordList/{IntToFloat {Length Note}}|Acc}
               end
            else
               if ({Label Note} == silence) then
                  if I >= Note.duration*44100.0 - 1.0 then Acc
                  else
                     {NoteToSampleAcc Note I+1.0 0.0|Acc}
                  end
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
      % Transformer une partition en liste de frequences
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
      % Liste de frequences d'un fichier .wav 
      fun {Wave FileName}
         {Project.readFile FileName}
      end
      % Fusionner des musiques en multipliant par des facteurs
      fun {Merge Musics}
         % Transformer les musiques en frequences
         fun {MSample Ms Acc}
            case Ms of nil then Acc
            [] H|T then 
               case H
               of I#M then {MSample T I#{Mixer M}|Acc}
               end
            end
         end
         SampleMusics = {MSample Musics nil}
         % Fusionner les listes de frequences
         fun {MergeSamples Ms Acc}
            AllNil = {NewCell true} % Toutes les musiques sont nil
            SumM = {NewCell 0.0} % Somme des frequences des elements initiales
            % Passer aux prochains elements des musiques
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
            Nxt = {NextSamples Ms nil} % Prochains elements des frequences des musiques
         in
            % Verifier si toutes les musiques sont saturées
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
               % Somme des frequences
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

      % Inverser une musique
      fun {Reverse Music}
         {Reverser {Mixer Music} nil}
      end

      % Repeter une musique
      fun {RepeatAcc N Music Acc}
         if N=<0 then
            Acc
         else
            {RepeatAcc N-1 Music Music|Acc}
         end
      end
      % Repeter une musique
      fun {Repeat N Music}
         {Flatten {RepeatAcc N {Mixer Music} nil}}
      end
      % Repeter une musique pendant une durée
      fun {Loop Duration Music}
         fun {GetPart X M Acc}
            if X =< 0.0 then Acc
            else
               case M of nil then Acc
               [] H|T then {GetPart X-1.0 T H|Acc}
               end
            end
         end
         M = {Mixer Music}
         N = ({FloatToInt Duration*44100.0} div {Length M})
         D = (Duration*44100.0 / {IntToFloat {Length M}}) - {IntToFloat N}
      in
         {Flatten {RepeatAcc N M nil}|{Reverser {GetPart {IntToFloat {Length M}}*D M nil} nil}}
      end
      % Limiter les frequences de la musique
      fun {Clip Low High Music}
         fun {ClipAcc Low High Music Acc}
            case Music of nil then Acc
            [] H|T then
               if H < Low then {ClipAcc Low High T Low|Acc}
               else
                  if H > High then {ClipAcc Low High T High|Acc}
                  else
                     {ClipAcc Low High T H|Acc}
                  end
               end
            end
         end
      in
         {Reverser {ClipAcc Low High {Mixer Music} nil} nil}
      end
      % Ajouter un echo a la musique
      fun {Echo Delay Decay Music}
         %{Merge [Decay#{Flatten [partition([duration([silence] seconds:Delay)])|Music]}]}
         {Merge [Decay#{Flatten partition([duration([silence] seconds:Delay)])|Music} (1.0-Decay)#Music]}
      end
      % Adoucir les transition de musique
      fun {Fade In Out Music}
         fun {FadeAcc In Out Music Count Acc}
            case Music of nil then Acc
            [] H|T then
               if (Len - Count) < In then
                  {FadeAcc In Out T Count-1.0 (H*((Len - Count)/In))|Acc}
               else
                  if Count < Out then
                     {FadeAcc In Out T Count-1.0 (H*(Count/Out))|Acc}
                  else
                     {FadeAcc In Out T Count-1.0 H|Acc}
                  end
               end
            end
         end
         M = {Mixer Music}
         Len = {IntToFloat {Length M}}
      in
         {Reverser {FadeAcc In*44100.0 Out*44100.0 M Len nil} nil}
      end
      % Couper une musique
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
         M = {Mixer Music}
      in
         {Reverser {Flatten {EndCut ((End-Start)*44100.0) {StartCut (Start*44100.0) M} nil}} nil}
      end
      
      % Transformer une partie de la musique en frequences
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
         [] clip(low:Y1 high:Y2 X) then {Clip Y1 Y2 X}
         [] echo(delay:Y1 decay:Y2 X) then {Echo Y1 Y2 X}
         [] fade(start:Y1 out:Y2 X) then {Fade Y1 Y2 X}
         else
            Part
         end
      end
      % Transformer la musique en partitions
      fun {Mixer M}
         fun {Mixe M Acc}
            case M of nil then Acc
            [] H|T then {Mixe T {ToSample H}|Acc}
            else {ToSample M}
            end
         end
      in
         {Flatten {Reverser {Mixe M nil} nil}}
      end
   in
      {Flatten {Mixer Music}}
   end

   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

   Extensions = false

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
   %{Browse {PartitionToTimedList Music}}
   %{Browse {Mix PartitionToTimedList Music}}
   {Browse {Project.run Mix PartitionToTimedList Music 'out.wav'}}
   
   % Shows the total time to run your code.
   {Browse {IntToFloat {Time}-Start} / 1000.0}
end
