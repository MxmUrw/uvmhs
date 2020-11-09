module UVMHS.Lib.Pretty.Doc where

import UVMHS.Core

import UVMHS.Lib.IterS

import UVMHS.Lib.Pretty.Color
import UVMHS.Lib.Pretty.Annotation
import UVMHS.Lib.Pretty.RenderGroups

import qualified GHC.Stack as Stack

data PrettyParams = PrettyParams
  { punctuationFormat        ∷ Formats
  , keywordFormat            ∷ Formats
  , constructorFormat        ∷ Formats
  , operatorFormat           ∷ Formats
  , primitiveFormat          ∷ Formats
  , binderFormat             ∷ Formats
  , literalFormat            ∷ Formats
  , highlightFormat          ∷ Formats
  , headerFormat             ∷ Formats
  , commentFormat            ∷ Formats
  , errorFormat              ∷ Formats
  , lineNumberFormat         ∷ Formats
  , appLevel                 ∷ ℕ64
  } deriving (Eq,Ord,Show)
makeLenses ''PrettyParams

prettyParams₀ ∷ PrettyParams
prettyParams₀ = PrettyParams
  { punctuationFormat        = formats [FG darkGray]
  , keywordFormat            = formats [BD,FG yellow]
  , constructorFormat        = formats [BD,FG green]
  , operatorFormat           = formats [FG teal]
  , primitiveFormat          = formats [FG green]
  , binderFormat             = formats [FG blue]
  , literalFormat            = formats [FG red]
  , highlightFormat          = formats [BG highlight]
  , headerFormat             = formats [BD,UL,FG pink]
  , commentFormat            = formats [IT,FG lightGray]
  , errorFormat              = formats [FG white,BG red]
  , lineNumberFormat         = formats [FG lightGray]
  , appLevel                 = 𝕟64 100
  }

data DocEnv = DocEnv
  -- global env
  { docEnvPrettyParams ∷ PrettyParams
  -- local env
  , docEnvPrecLevel ∷ ℕ64
  , docEnvPrecBumped ∷ 𝔹
  } deriving (Eq,Ord,Show)
makeLenses ''DocEnv

docEnv₀ ∷ DocEnv
docEnv₀ = DocEnv
  -- global env
  { docEnvPrettyParams = prettyParams₀
  -- local env
  , docEnvPrecLevel = 𝕟64 0
  , docEnvPrecBumped = False
  }

type DocM = RWS DocEnv RenderGroups ()
newtype Doc = Doc { unDoc ∷ DocM () }

execDocWith ∷ (DocM () → DocM ()) → Doc → RenderGroups
execDocWith f = evalRWS docEnv₀ () ∘ retOut ∘ f ∘ unDoc

execDoc ∷ Doc → RenderGroups
execDoc = execDocWith id

onDoc ∷ (DocM () → DocM ()) → Doc → Doc
onDoc f (Doc xM) = Doc $ f xM

onDoc2 ∷ (DocM () → DocM () → DocM ()) → Doc → Doc → Doc
onDoc2 f (Doc xM₁) (Doc xM₂) = Doc $ f xM₁ xM₂

instance Null Doc where null = Doc skip
instance Append Doc where (⧺) = onDoc2 (≫)
instance Monoid Doc

-----------------
-- COMBINATORS --
-----------------

ppAnnotate ∷ Annotation → Doc → Doc
ppAnnotate = onDoc ∘ mapOut ∘ annotateRenderGroups

ppFormat ∷ Formats → Doc → Doc
ppFormat = ppAnnotate ∘ formatAnnotation

ppFormatParam ∷ PrettyParams ⟢ Formats → Doc → Doc
ppFormatParam l d = Doc $ do
  fmt ← askL $ l ⊚ docEnvPrettyParamsL
  unDoc $ ppFormat fmt d

ppUndertag ∷ ℂ → Formats → Doc → Doc
ppUndertag = ppAnnotate ∘∘ undertagAnnotation

ppGroup ∷ Doc → Doc
ppGroup = onDoc $ mapOut groupRenderGroups

ppAlign ∷ Doc → Doc
ppAlign = onDoc $ mapOut alignRenderGroups

ppGA ∷ Doc → Doc
ppGA = ppAlign ∘ ppGroup

ppString ∷ 𝕊 → Doc
ppString = Doc ∘ tell ∘ stringCChunk

ppStringModal ∷ 𝕊 → 𝕊 → Doc
ppStringModal sf sb = Doc $ tell $ stringCChunkModal sf sb

ppFG ∷ Color → Doc → Doc
ppFG c = ppFormat $ formats [FG c]

ppBG ∷ Color → Doc → Doc
ppBG c = ppFormat $ formats [BG c]

ppUL ∷ Doc → Doc
ppUL = ppFormat $ formats [UL]

ppBD ∷ Doc → Doc
ppBD = ppFormat $ formats [BD]

ppIT ∷ Doc → Doc
ppIT = ppFormat $ formats [IT]

ppUT ∷ ℂ → Color → Doc → Doc
ppUT c o = ppUndertag c (formats [FG o])

ppPun ∷ 𝕊 → Doc
ppPun = ppFormatParam punctuationFormatL ∘ ppString

ppKey ∷ 𝕊 → Doc
ppKey = ppFormatParam keywordFormatL ∘ ppString

ppCon ∷ 𝕊 → Doc
ppCon = ppFormatParam constructorFormatL ∘ ppString

ppOp ∷ 𝕊 → Doc
ppOp = ppFormatParam operatorFormatL ∘ ppString

ppPrim ∷ 𝕊 → Doc
ppPrim = ppFormatParam primitiveFormatL ∘ ppString

ppBdr ∷ 𝕊 → Doc
ppBdr = ppFormatParam binderFormatL ∘ ppString

ppLit ∷ 𝕊 → Doc
ppLit = ppFormatParam literalFormatL ∘ ppString

ppHl ∷ 𝕊 → Doc
ppHl = ppFormatParam highlightFormatL ∘ ppString

ppHeader ∷ 𝕊 → Doc
ppHeader = ppFormatParam headerFormatL ∘ ppString

ppComment ∷ 𝕊 → Doc
ppComment = ppFormatParam commentFormatL ∘ ppString

ppErr ∷ 𝕊 → Doc
ppErr = ppFormatParam errorFormatL ∘ ppString


ppSpace ∷ ℕ64 → Doc
ppSpace n = ppString $ string $ repeat (nat n) ' '

ppNewline ∷ Doc
ppNewline = ppString "\n"

ppSpaceIfBreak ∷ Doc
ppSpaceIfBreak = ppStringModal "" " "

ppNewlineIfBreak ∷ Doc
ppNewlineIfBreak = ppStringModal "" "\n"

ppSpaceNewlineIfBreak ∷ Doc
ppSpaceNewlineIfBreak = ppStringModal " " "\n"


ppHorizontal ∷ (ToIter Doc t) ⇒ t → Doc
ppHorizontal = concat ∘ inbetween (ppSpace $ 𝕟64 1) ∘ iter

ppVertical ∷ (ToIter Doc t) ⇒ t → Doc
ppVertical = concat ∘ inbetween ppNewline ∘ iter

ppSeparated ∷ (ToIter Doc t) ⇒ t → Doc
ppSeparated = ppGroup ∘ concat ∘ inbetween ppSpaceNewlineIfBreak ∘ iter

ppSetLevel ∷ ℕ64 → Doc → Doc
ppSetLevel n = onDoc $ mapEnv $ update docEnvPrecLevelL n ∘ update docEnvPrecBumpedL False

ppSetBotLevel ∷ Doc → Doc
ppSetBotLevel = ppSetLevel zero

ppBump ∷ Doc → Doc
ppBump = onDoc $ mapEnv $ update docEnvPrecBumpedL True

ppClosed ∷ Doc → Doc → Doc → Doc
ppClosed alM arM aM = ppSetBotLevel $ concat
  [ alM
  , ppGA aM
  , arM
  ]

ppParens ∷ Doc → Doc
ppParens = ppClosed (ppPun "(") (ppPun ")")

ppLevel ∷ ℕ64 → Doc → Doc
ppLevel i' aM = Doc $ do
  i ← askL $ docEnvPrecLevelL
  b ← askL $ docEnvPrecBumpedL
  unDoc $ case (i < i') ⩔ ((i ≡ i') ⩓ not b) of
    True → ppSetLevel i' aM
    False → ppParens $ ppSetLevel i' aM

ppInfLevel ∷ ℕ64 → Doc → Doc → Doc → Doc
ppInfLevel i oM x₁M x₂M = ppLevel i $ concat $ iter [ppBump x₁M,oM,ppBump x₂M]

ppInflLevel ∷ ℕ64 → Doc → Doc → Doc → Doc
ppInflLevel i oM x₁M x₂M = ppLevel i $ concat $ iter [x₁M,oM,ppBump x₂M]

ppInfrLevel ∷ ℕ64 → Doc → Doc → Doc → Doc
ppInfrLevel i oM x₁M x₂M = ppLevel i $ concat $ iter [ppBump x₁M,oM,x₂M]

ppPreLevel ∷ ℕ64 → Doc → Doc → Doc
ppPreLevel i oM xM = ppLevel i $ concat $ iter [oM,xM]

ppPostLevel ∷ ℕ64 → Doc → Doc → Doc
ppPostLevel i oM xM = ppLevel i $ concat $ iter [xM,oM]

ppInf ∷ ℕ64 → Doc → Doc → Doc → Doc
ppInf i o = ppInfLevel i $ concat [ppNewlineIfBreak,o,ppSpaceIfBreak]

ppInfl ∷ ℕ64 → Doc → Doc → Doc → Doc
ppInfl i o = ppInflLevel i $ concat [ppNewlineIfBreak,o,ppSpaceIfBreak]

ppInfr ∷ ℕ64 → Doc → Doc → Doc → Doc
ppInfr i o = ppInfLevel i $ concat [ppNewlineIfBreak,o,ppSpaceIfBreak]

ppPre ∷ ℕ64 → Doc → Doc → Doc
ppPre = ppPreLevel

ppPost ∷ ℕ64 → Doc → Doc → Doc
ppPost = ppPostLevel

ppApp ∷ (ToIter Doc t) ⇒ Doc → t → Doc
ppApp x xs 
  | count xs ≡ zero = ppAlign x
  | otherwise = ppGA $ Doc $ do
    l ← askL $ appLevelL ⊚ docEnvPrettyParamsL
    unDoc $ ppLevel l $ ppGroup $ concat 
      [ ppAlign x
      , ppSpaceNewlineIfBreak
      , concat $ inbetween ppSpaceNewlineIfBreak $ map (ppAlign ∘ ppBump) $ iter xs
      ]

ppCollection ∷ (ToIter Doc t) ⇒ Doc → Doc → Doc → t → Doc
ppCollection l r i xs = ppGA $ ppSetBotLevel $ concat
  [ l
  , ppSpaceIfBreak
  , concat $ inbetween spacer $ iter xs
  , ppNewlineIfBreak
  , r
  ]
  where
    spacer ∷ Doc
    spacer = concat
      [ ppNewlineIfBreak
      , i
      , ppSpaceIfBreak
      ]

ppRecord ∷ (ToIter (Doc ∧ Doc) t) ⇒ Doc → t → Doc
ppRecord rel kvs = ppCollection (ppPun "{") (ppPun "}") (ppPun ",") $ map mapping $ iter kvs
  where
    mapping (k :* v) = ppGroup $ concat
      [ ppAlign k
      , ppSpaceIfBreak
      , rel
      , ppNewlineIfBreak
      , ppSpaceIfBreak
      , ppSpaceIfBreak
      , ppAlign v
      ]

-----------
-- CLASS --
-----------

class Pretty a where 
  pretty ∷ a → Doc

instance Pretty Doc where pretty = id
instance Pretty () where pretty = ppCon ∘ show𝕊
instance Pretty 𝔹 where pretty = ppCon ∘ show𝕊
instance Pretty ℕ where pretty = ppLit ∘ show𝕊
instance Pretty ℕ64 where pretty = ppLit ∘ show𝕊
instance Pretty ℕ32 where pretty = ppLit ∘ show𝕊
instance Pretty ℕ16 where pretty = ppLit ∘ show𝕊
instance Pretty ℕ8 where pretty = ppLit ∘ show𝕊
instance Pretty ℤ where pretty = ppLit ∘ show𝕊
instance Pretty ℤ64 where pretty = ppLit ∘ show𝕊
instance Pretty ℤ32 where pretty = ppLit ∘ show𝕊
instance Pretty ℤ16 where pretty = ppLit ∘ show𝕊
instance Pretty ℤ8 where pretty = ppLit ∘ show𝕊
instance Pretty ℚ where pretty = ppLit ∘ show𝕊
instance Pretty ℚᴾ where pretty = ppLit ∘ show𝕊
instance Pretty 𝔻  where pretty = ppLit ∘ show𝕊
instance Pretty 𝔻ᴾ  where pretty (𝔻ᴾ d) = ppLit $ show𝕊 d
instance Pretty ℝ  where 
  pretty = \case 
    Integer i → pretty i 
    Rational q → pretty q 
    Double d → pretty d
instance Pretty ℝᴾ  where 
  pretty = \case 
    Natural n → pretty n 
    Rationalᴾ q → pretty q 
    Doubleᴾ d → pretty d

instance Pretty Time where pretty = ppLit ∘ show𝕊

escape ∷ ℂ → 𝐼 ℂ
escape = \case
  '"' → iter "\\\""
  '\\' → iter "\\\\"
  '\n' → iter "\\n"
  '\t' → iter "\\t"
  '\r' → iter "\\r"
  '\b' → iter "\\b"
  '\f' → iter "\\f"
  c' → single c'

instance Pretty ℂ where 
  pretty c = ppLit $ string $ concat
    [ iter "'"
    , escape c
    , iter "'"
    ]

instance Pretty 𝕊 where 
  pretty s = ppLit $ string $ concat
    [ iter "\""
    , escape *$ iter s
    , iter "\""
    ]

instance (Pretty a,Pretty b) ⇒ Pretty (a,b) where
  pretty (a,b) = ppCollection (ppPun "(") (ppPun ")") (ppPun ",") [pretty a, pretty b]
instance (Pretty a,Pretty b) ⇒ Pretty (a ∧ b) where
  pretty (a :* b) = ppCollection (ppPun "⟨") (ppPun "⟩") (ppPun ",") [pretty a, pretty b]

instance (Pretty a) ⇒ Pretty (𝐿 a) where 
  pretty = ppCollection (ppPun "[") (ppPun "]") (ppPun ",") ∘ map pretty ∘ iter
instance (Pretty a) ⇒ Pretty [a] where 
  pretty = ppCollection (ppPun "[") (ppPun "]") (ppPun ",") ∘ map pretty ∘ iter
instance (Pretty a) ⇒ Pretty (𝕍 a) where 
  pretty xs = ppApp (ppString "𝕍") $ list [pretty $ list xs]
instance (Pretty a) ⇒ Pretty (𝑆 a) where 
  pretty xs = ppApp (ppString "𝑆") $ list [pretty $ list xs]
instance (Pretty a) ⇒ Pretty (𝐼 a) where 
  pretty xs = ppApp (ppString "𝐼") $ list [pretty $ list xs]
instance (Pretty a) ⇒ Pretty (𝐼S a) where 
  pretty xs = ppApp (ppString "𝐼S") $ list [pretty $ list xs]
instance (Pretty a) ⇒ Pretty (𝑄 a) where 
  pretty xs = ppApp (ppString "𝑄") $ list [pretty $ list xs]
instance (Pretty a) ⇒ Pretty (𝑃 a) where 
  pretty = ppCollection (ppPun "{") (ppPun "}") (ppPun ",") ∘ map pretty ∘ iter
instance (Pretty k,Pretty v) ⇒ Pretty (k ⇰ v) where 
  pretty = ppRecord (ppPun "↦") ∘ map (mapPair pretty pretty) ∘ iter

instance (Pretty a) ⇒ Pretty (AddNull a) where
  pretty Null = ppCon "•"
  pretty (AddNull x) = pretty x

instance (Pretty a) ⇒ Pretty (AddBot a) where
  pretty Bot = ppCon "⊥"
  pretty (AddBot x) = pretty x

instance (Pretty a) ⇒ Pretty (AddTop a) where
  pretty Top = ppCon "⊤"
  pretty (AddTop x) = pretty x

instance (Pretty a) ⇒ Pretty (AddBT a) where
  pretty BotBT = ppCon "⊥"
  pretty TopBT = ppCon "⊤"
  pretty (AddBT x) = pretty x

instance Pretty Stack.CallStack where pretty = ppString ∘ string ∘ Stack.prettyCallStack
