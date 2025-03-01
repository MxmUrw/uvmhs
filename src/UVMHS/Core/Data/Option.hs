module UVMHS.Core.Data.Option where

import UVMHS.Core.Init
import UVMHS.Core.Classes

import qualified Prelude as HS

instance Functor 𝑂 where 
  map = mmap
instance Return 𝑂 where 
  return = Some
instance Bind 𝑂 where 
  xO ≫= k = case xO of {None → None;Some x → k x}
instance Monad 𝑂
instance FunctorM 𝑂 where 
  mapM f = \case
    None → return None
    Some x → Some ^$ f x
instance (Null a) ⇒ Null (𝑂 a) where 
  null = Some null
instance (Append a) ⇒ Append (𝑂 a) where
  None ⧺ _ = None
  _ ⧺ None = None
  Some x ⧺ Some y = Some $ x ⧺ y
instance (Monoid a) ⇒ Monoid (𝑂 a)

instance ToIter a (𝑂 a) where iter = iter𝑂

iter𝑂 ∷ 𝑂 a → 𝐼 a
iter𝑂 xO = 𝐼 HS.$ \ f i 𝓀 → case xO of
    None → 𝓀 i
    Some x → f x i 𝓀

instance 𝑂 a ⇄ (() ∨ a) where
  isoto = \case
    None → Inl ()
    Some x → Inr x
  isofr = \case
    Inl () → None
    Inr x → Some x

elim𝑂 ∷ b → (a → b) → 𝑂 a → b
elim𝑂 n s = \case
  None → n
  Some x → s x

elim𝑂Z ∷ b → (a → b) → 𝑂 a → b
elim𝑂Z ~n ~s = \case
  None → n
  Some x → s x

isNone ∷ 𝑂 a → 𝔹
isNone = \case
  None → True
  Some _ → False

isSome ∷ 𝑂 a → 𝔹
isSome = \case
  None → False
  Some _ → True

ifNone ∷ a → 𝑂 a → a
ifNone i = \case
  None → i
  Some x → x

ifNoneZ ∷ a → 𝑂 a → a
ifNoneZ ~i = \case
  None → i
  Some x → x

ifNoneM ∷ (Return m) ⇒ m a → 𝑂 a → m a
ifNoneM xM = \case
  None → xM
  Some x → return $ x

ifNoneMZ ∷ (Return m) ⇒ m a → 𝑂 a → m a
ifNoneMZ ~xM = \case
  None → xM
  Some x → return $ x

first ∷ 𝑂 a → 𝑂 a → 𝑂 a
first = \case
  None → id
  Some x → const $ Some x

last ∷ 𝑂 a → 𝑂 a → 𝑂 a
last = flip first
