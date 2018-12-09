module UVMHS.Core.Data.String where

import UVMHS.Init
import UVMHS.Core.Classes

import UVMHS.Core.Data.Arithmetic ()

import qualified Data.Text              as Text
import qualified Data.Text.Lazy         as TextLazy
import qualified Data.Text.Lazy.Builder as TextBuilder
import qualified Prelude                as HS

instance Null 𝕊 where null = Text.empty
instance Append 𝕊 where (⧺) = Text.append
instance Monoid 𝕊

instance Single ℂ 𝕊 where single = Text.singleton

instance ToStream ℂ 𝕊 where stream = streamLL ∘ chars
instance ToIter ℂ 𝕊 where iter = iter𝑆 ∘ stream

empty𝕊 ∷ 𝕊 → 𝔹
empty𝕊 = Text.null

single𝕊 ∷ ℂ → 𝕊
single𝕊 = Text.singleton

build𝕊 ∷ (ToIter 𝕊 t) ⇒ t → 𝕊
build𝕊 = TextLazy.toStrict ∘ TextBuilder.toLazyText ∘ foldr𝐼 HS.mempty (HS.mappend ∘ TextBuilder.fromText) ∘ iter

show𝕊 ∷ (Show a) ⇒ a → 𝕊
show𝕊 = fromChars ∘ HS.show

read𝕊 ∷ (HS.Read a) ⇒ 𝕊 → a
read𝕊 = HS.read ∘ chars

lower𝕊 ∷ 𝕊 → 𝕊
lower𝕊 = Text.toLower

upper𝕊 ∷ 𝕊 → 𝕊
upper𝕊 = Text.toUpper

isEmpty𝕊 ∷ 𝕊 → 𝔹
isEmpty𝕊 = Text.null

splitOn𝕊 ∷ 𝕊 → 𝕊 → 𝐿 𝕊
splitOn𝕊 i s = frhs $ Text.splitOn i s

length𝕊 ∷ 𝕊 → ℕ
length𝕊 = natΩ ∘ frhs ∘ Text.length
