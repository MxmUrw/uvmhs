module UVMHSContrib.Lang.SExp where

import UVMHS

lexer ∷ Lexer CharClass ℂ TokenClassBasic ℕ64 TokenBasic
lexer = lexerBasic (list ["(",")"]) (list ["KEY"]) (list ["PRIM"]) (list ["+"])

testSExpTokenizerSuccess ∷ IO ()
testSExpTokenizerSuccess = 
  tokenizeIOMain lexer "" $ prepTokens $ tokens "((-1-2-1.42(\"astringwith\\\\stuff\\n\" ( "

testSExpTokenizerFailure1 ∷ IO ()
testSExpTokenizerFailure1 =
  tokenizeIOMain lexer "" $ prepTokens $ tokens "((foo-1and0.01+bar"

testSExpTokenizerFailure2 ∷ IO ()
testSExpTokenizerFailure2 =
  tokenizeIOMain lexer "" $ prepTokens $ tokens "()foo-1\"astring\\badescape\""

data Lit =
    IntegerL ℤ
  | DoubleL 𝔻
  | StringL 𝕊
makePrettySum ''Lit

data Atom =
    LitA Lit
  | NameA 𝕊
  | KeyA
  | PrimA
  | PlusA
makePrettySum ''Atom

type Exp = Annotated FullContext ExpPre
data ExpPre =
    AtomE Atom
  | ListE (𝐿 Exp)
makePrettySum ''ExpPre

------------
-- Parser --
------------

cpLit ∷ CParser TokenBasic Lit
cpLit = concat
  [ IntegerL ^$ cpShaped $ view integerTBasicL
  , DoubleL ^$ cpShaped $ view doubleTBasicL
  , StringL ^$ cpShaped $ view stringTBasicL
  ]

cpAtom ∷ CParser TokenBasic Atom
cpAtom = cpNewContext "atom" $ concat
  [ cpErr "literal" $ LitA ^$ cpLit
  , cpErr "name" $ NameA ^$ cpShaped $ view nameTBasicL
  , cpErr "keyword" $ const KeyA ^$ cpSyntax "KEY"
  , cpErr "primitive" $ const PrimA ^$ cpSyntax "PRIM"
  , cpErr "“+”" $ const PlusA ^$ cpSyntax "+"
  ]

cpExp ∷ CParser TokenBasic Exp
cpExp = cpNewContext "expression" $ cpWithContextRendered $ concat
  [ AtomE ^$ cpAtom
  , ListE ^$ cpList
  ]

cpList ∷ CParser TokenBasic (𝐿 Exp)
cpList = cpNewContext "list" $ do
  cpErr "“(”" $ void $ cpSyntax "("
  es ← cpMany cpExp
  cpErr "“)”" $ void $ cpSyntax ")"
  return es

testSExpParserSuccess ∷ IO ()
testSExpParserSuccess = do
  tokenizeIOMain lexer "" input
  toks ← prepTokens ^$ tokenizeIO lexer "" input
  parseIOMain cpExp "" $ stream toks
  where
    input ∷ 𝕍 (ParserToken ℂ)
    input = prepTokens $ tokens " ( PRIM KEY x + y  {- yo -} ( -1-2)  0.0 \n x   y   z \n abc -12  )  "

testSExpParserFailure1 ∷ IO ()
testSExpParserFailure1 = do
  tokenizeIOMain lexer "" input
  toks ← prepTokens ^$ tokenizeIO lexer "" input
  parseIOMain cpExp "" $ stream toks
  where
    input ∷ 𝕍 (ParserToken ℂ)
    input = prepTokens $ tokens " (( PRIM KEY x + y  {- yo -} ( -1-2)  0.0 \n x   y   z \n abc -12 )  "

testSExpParserFailure2 ∷ IO ()
testSExpParserFailure2 = do
  tokenizeIOMain lexer "" input
  toks ← prepTokens ^$ tokenizeIO lexer "" input
  parseIOMain cpExp "" $ stream toks
  where
    input ∷ 𝕍 (ParserToken ℂ)
    input = prepTokens $ tokens " )( PRIM KEY x + y  {- yo -} ( -1-2)  0.0 \n x   y   z \n abc -12 )  "

testSExpParserFailure3 ∷ IO ()
testSExpParserFailure3 = do
  tokenizeIOMain lexer "" input
  toks ← prepTokens ^$ tokenizeIO lexer "" input
  parseIOMain cpExp "" $ stream toks
  where
    input ∷ 𝕍 (ParserToken ℂ)
    input = prepTokens $ tokens " ( PRIM KEY x + y  {- yo -} ( -1-2)  0.0 \n x   y   z \n abc -12 )(  "
