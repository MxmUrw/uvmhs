module UVMHS.Lib.Pretty.RenderANSI where

import UVMHS.Core

import UVMHS.Lib.IterS
import UVMHS.Lib.ATree

import UVMHS.Lib.Pretty.Annotation
import UVMHS.Lib.Pretty.Common
import UVMHS.Lib.Pretty.Doc
import UVMHS.Lib.Pretty.RenderGroups
import UVMHS.Lib.Pretty.RenderUndertags

import Data.IORef (IORef)
import qualified Data.IORef as IORef

data ANSIEnv = ANSIEnv
  -- global env
  { ansiEnvDoFormat ∷ 𝔹
  -- local env
  , ansiEnvFormats ∷ Formats
  } deriving (Eq,Ord,Show)
makeLenses ''ANSIEnv

ansiEnv₀ ∷ ANSIEnv
ansiEnv₀ = ANSIEnv True null

type RenderANSIM = RWS ANSIEnv 𝐼S𝕊 ()

sgrLeader ∷ 𝕊
sgrLeader = "\ESC["

sgrCloser ∷ 𝕊
sgrCloser = "m"

sgrReset ∷ 𝕊
sgrReset = sgrLeader ⧺ "0" ⧺ sgrCloser

sgrFg ∷ 𝑂 Color → 𝕊
sgrFg None = "39"
sgrFg (Some (Color c)) = case c of
  Black → "90"
  Red → "91"
  Green → "92"
  Yellow → "93"
  Blue → "94"
  Magenta → "95"
  Cyan → "96"
  White → "97"
sgrFg (Some (Color8 c)) = "38;5;" ⧺ show𝕊 c
sgrFg (Some (Color24 r g b)) = "38;2;" ⧺ show𝕊 r ⧺ ";" ⧺ show𝕊 g ⧺ ";" ⧺ show𝕊 b

sgrBg ∷ 𝑂 Color → 𝕊
sgrBg None = "49"
sgrBg (Some (Color c)) = case c of
  Black → "100"
  Red → "101"
  Green → "102"
  Yellow → "103"
  Blue → "104"
  Magenta → "105"
  Cyan → "106"
  White → "107"
sgrBg (Some (Color8 c)) = "48;5;" ⧺ show𝕊 c
sgrBg (Some (Color24 r g b)) = "48;2;" ⧺ show𝕊 r ⧺ ";" ⧺ show𝕊 g ⧺ ";" ⧺ show𝕊 b

sgrUl ∷ 𝔹 → 𝕊
sgrUl True = "4"
sgrUl False = "24"

sgrBd ∷ 𝔹 → 𝕊
sgrBd True = "1"
sgrBd False = "22"

sgrIt ∷ 𝔹 → 𝕊
sgrIt True = "3"
sgrIt False = "23"

sgrFormat ∷ Formats → 𝐼S𝕊
sgrFormat (Formats fg bg ul bd it) = single $ stringC $ iter
  [ sgrLeader 
  , concat $ inbetween ";" $ mconcat $ map (mzero𝑂 @ 𝑄) $ iter
      [ sgrFg ^$ fg
      , sgrBg ^$ bg
      , sgrUl ^$ ul
      , sgrBd ^$ bd
      , sgrIt ^$ it
      ]
  , sgrCloser
  ]

tellSgrFormat ∷ RenderANSIM ()
tellSgrFormat = do
  cf ← askL ansiEnvFormatsL
  tell $ sgrFormat cf

localFormat ∷ Formats → RenderANSIM () → RenderANSIM ()
localFormat f aM = do
  mapEnvL ansiEnvFormatsL (prepend f) $ do
    tellSgrFormat
    aM
  tell $ single sgrReset
  tellSgrFormat

renderChunk' ∷ OChunk → 𝐼S𝕊
renderChunk' = \case
  RawOChunk n s → 𝐼S𝕊 n $ single s
  NewlineOChunk → single "\n"
  PaddingOChunk n → 𝐼S𝕊 n $ single $ string $ repeat (nat n) ' '
  
formatRenderANSI ∷ Formats → RenderANSIM () → RenderANSIM ()
formatRenderANSI fm xM = do
  b ← askL ansiEnvDoFormatL
  case b of
    True → localFormat fm xM
    False → xM

compileOTree ∷ OTree → RenderANSIM ()
compileOTree sd = un𝑉𝐴 sd fₑ fₐ
  where
    fₑ chs = eachWith (tell ∘ renderChunk') chs
    fₐ fm = formatRenderANSI fm

execRenderANSIWith ∷ (RenderANSIM () → RenderANSIM ()) → OTree → 𝐼S𝕊
execRenderANSIWith f = evalRWS ansiEnv₀ () ∘ retOut ∘ f ∘ compileOTree

execRenderANSI ∷ OTree → 𝐼S𝕊
execRenderANSI = execRenderANSIWith id

-- execOTreeWith ∷ (RenderANSIM () → RenderANSIM ()) → OTree → 𝕊
-- execOTreeWith f = {- stringCS ∘ evalRWS ansiEnv₀ () ∘ retOut ∘ f -} _ f ∘ compileOTree
-- 
-- execOTree ∷ ITree → 𝕊
-- execOTree = execOTreeWith id

ppRenderWith ∷ (RenderANSIM () → RenderANSIM ()) 
             → (RenderGroupsM () → RenderGroupsM ())
             → (DocM () → DocM ())
             → Doc → 𝕊
ppRenderWith f₁ f₃ f₄ =
  stringCS
  ∘ execRenderANSIWith f₁
  ∘ execRenderUT
  ∘ execRenderGroupsWith f₃
  ∘ execDocWith f₄

ppRender ∷ Doc → 𝕊
ppRender = ppRenderWith id id id

ppRenderNofmt ∷ Doc → 𝕊
ppRenderNofmt = ppRenderWith (localL ansiEnvDoFormatL False) id id

ppRenderWide ∷ Doc → 𝕊
ppRenderWide = 
  ppRenderWith id 
               (localL renderGroupsEnvMaxLineWidthL None ∘ localL renderGroupsEnvMaxRibbonWidthL None) 
               id

ppRenderNofmtWide ∷ Doc → 𝕊
ppRenderNofmtWide = 
  ppRenderWith (localL ansiEnvDoFormatL False) 
               (localL renderGroupsEnvMaxLineWidthL None ∘ localL renderGroupsEnvMaxRibbonWidthL None)
               id

ppshow ∷ (Pretty a) ⇒ a → 𝕊
ppshow = ppRenderNofmtWide ∘ pretty

gv_PPRINT_COLOR ∷ IORef 𝔹
gv_PPRINT_COLOR = ioUNSAFE $ IORef.newIORef True

pprint ∷ (Pretty a) ⇒ a → IO ()
pprint x = do
  b ← IORef.readIORef gv_PPRINT_COLOR
  if b
     then out $ ppRender $ pretty x
     else out $ ppRenderNofmt $ pretty x

ppColorOn ∷ IO ()
ppColorOn = IORef.writeIORef gv_PPRINT_COLOR True

ppColorOff ∷ IO ()
ppColorOff = IORef.writeIORef gv_PPRINT_COLOR False

pptrace ∷ (Pretty a) ⇒ a → b → b
pptrace a = ioUNSAFE $ do
  pprint a
  return id

pptraceM ∷ (Monad m,Pretty a) ⇒ a → m ()
pptraceM a = pptrace a skip

ioError ∷ (Pretty e) ⇒ e ∨ a → IO a
ioError = elimChoice (\ e → pprint e ≫ abortIO) return

{-
interpConsoleOutANSI ∷ ConsoleOut → RenderANSIM ()
interpConsoleOutANSI NullCO = skip
interpConsoleOutANSI (ChunkCO s) = tell $ single s
interpConsoleOutANSI (AppendCO o₁ o₂) = exec [interpConsoleOutANSI o₁,interpConsoleOutANSI o₂]
interpConsoleOutANSI (FormatCO f o) = localFormat f $ interpConsoleOutANSI o

execConsoleOutANSI ∷ ConsoleOut → 𝕊
execConsoleOutANSI = concat ∘ evalConsoleANSIM ∘ retOut ∘ interpConsoleOutANSI

pprenderWith ∷ (Pretty a) ⇒ (Doc → Doc) → a → 𝕊
pprenderWith f = execConsoleOutANSI ∘ execPrettyOut ∘ execDoc ∘ f ∘ pretty

pprenderWidth ∷ (Pretty a) ⇒ ℕ → a → 𝕊
pprenderWidth = pprenderWith ∘ onDoc ∘ mapEnv ∘ update maxColumnWidthL

pprender ∷ (Pretty a) ⇒ a → 𝕊
pprender = pprenderWith id

pprint ∷ (Pretty a) ⇒ a → IO ()
pprint = out ∘ pprender

pptrace ∷ (Pretty a) ⇒ a → b → b
pptrace a b = unsafePerformIO $ do
  pprint a
  return b

pptraceM ∷ (Monad m,Pretty a) ⇒ a → m ()
pptraceM a = pptrace a skip

ioError ∷ (Pretty e) ⇒ e ∨ a → IO a
ioError = elimChoice (\ e → pprint e ≫ abortIO) return
-}
