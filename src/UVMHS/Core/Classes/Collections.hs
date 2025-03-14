module UVMHS.Core.Classes.Collections where

import UVMHS.Core.Init

infixl 7 ⋕?,⋕,⋕!

class All a where all ∷ 𝐼 a

class Single a t | t → a where single ∷ a → t
class Lookup k v t | t → k,t → v where (⋕?) ∷ t → k → 𝑂 v
class Access k v t | t → k,t → v where (⋕) ∷ t → k → v

class ToIter a t | t → a where iter ∷ t → 𝐼 a

(⋕!) ∷ (Lookup k v t,STACK) ⇒ t → k → v
kvs ⋕! k = case kvs ⋕? k of
  Some v → v
  None → error "failed ⋕! lookup"
