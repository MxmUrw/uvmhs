module UVMHS.Lib.Substitution where

import UVMHS.Core
import UVMHS.Lib.Pretty
import UVMHS.Lib.Testing
import UVMHS.Lib.Annotated
import UVMHS.Lib.Rand
import UVMHS.Lib.Variables
import UVMHS.Lang.ULCD

--------------
-- CORE LIB --
--------------

-- subst(ρ,vs,ι)(𝓍) =
--   𝓍      if  𝓍 < ρ
--   vs(𝓍)  if  𝓍 ≥ ρ  ∧  𝓍 - ρ < |vs|
--   𝓍+ι    if  𝓍 ≥ ρ  ∧  𝓍 - ρ ≥ |vs|
data Subst a = Subst
  { substShft ∷ ℕ64
  --               variable    term
  --               ↓↓↓         ↓
  , substVals ∷ 𝕍 (ℕ64 ∨ ℕ64 ∧ a)
  --                     ↑↑↑↑
  --                     shifted
  , substIncr ∷ ℤ64
  --                       term
  --                       ↓
  , substGlbl ∷ 𝕏 ⇰ (ℕ64 ∧ a)
  --                 ↑↑↑
  --                 shifted
  } deriving (Eq,Ord,Show)
makePrettyRecord ''Subst

class HasSubst a where
  subst ∷ Subst a → a → a

class HasSubstX e a | a → e where
  substx ∷ b ⌲ e → Subst b → a → 𝑂 a

wfSubst ∷ Subst a → 𝔹
wfSubst (Subst _ρ vs ι _gs) = and
  -- `|vs| + ι` should be non-negative
  [ intΩ64 (csize vs) + ι ≥ 𝕫64 0
  ]

-- subst(id)(𝓍) = 𝓍
-- id ≜ (0,∅,0)
nullSubst ∷ Subst a
nullSubst = Subst
  { substShft = 𝕟64 0
  , substVals = vec []
  , substIncr = 𝕫64 0
  , substGlbl = dø
  }

-- subst(intro)(𝓍) = 𝓍+1
-- intro ≜ (0,∅,1)
intrSubst ∷ ℕ64 → Subst a
intrSubst 𝓍 = Subst
  { substShft = 𝕟64 0
  , substVals = vec []
  , substIncr = intΩ64 𝓍
  , substGlbl = dø
  }

-- subst(bind(v))(𝓍) =
--   v    if  𝓍 = 0
--   𝓍-1  if  𝓍 > 0
-- bind(v) ≜ (0,{0↦v},-1)
bindSubst ∷ a → Subst a
bindSubst v = Subst
  { substShft = 𝕟64 0
  , substVals = vec [Inr $ 𝕟64 0 :* v]
  , substIncr = neg $ 𝕫64 1
  , substGlbl = dø
  }

-- subst(shftSubst[n](ρ,vs,ι))(𝓍) = subst(ρ,vs,ι)(𝓍+n)
-- shftSubst[n](ρ,vs,ι) ≜ (ρ′,vs′,ι)
--   where
--     ρ′ = ρ+n
--     vs′(n′) = 
--       𝓍+n       if  vs(n′) = 𝓍
--       (ρₑ+n,e)  if  vs(n′) = (ρₑ,e)
shftSubst ∷ ℕ64 → Subst a → Subst a
shftSubst n (Subst ρ vs ι gs) = 
  let ρ' = ρ + n
      vs' = mapOn vs $ \case
        Inl 𝓍 → Inl $ 𝓍 + n
        Inr (ρₑ :* e) → Inr $ (ρₑ + n) :* e
      gs' = mapOn gs $ \ (ρₑ :* e) → (ρₑ + n) :* e
  in Subst ρ' vs' ι gs'

appendSubst ∷ (HasSubst a) ⇒ Subst a → Subst a → Subst a
appendSubst 𝓈₂@(Subst ρ₂ vs₂ ι₂ gs₂) (Subst ρ₁ vs₁ ι₁ gs₁) =
  let ρ = ρ₁ ⊓ ρ₂
      logicalSize = natΩ64 $ joins
        [ intΩ64 $ csize vs₁ + ρ₁
        , intΩ64 (csize vs₂) + intΩ64 ρ₂ - ι₁
        ]
      vsSize = logicalSize - ρ
      vsOffset₁ = ρ₁ - ρ
      ι = ι₁ + ι₂
      vs = vecF vsSize $ \ 𝓍 → 
        if 𝓍 < vsOffset₁
        then bvsubst 𝓈₂ $ ρ + 𝓍
        else
          case vs₁ ⋕? (𝓍 - vsOffset₁) of
            Some v → case v of
              Inl 𝓍' → bvsubst 𝓈₂ 𝓍'
              Inr (ρₑ :* e) → Inr $ 𝕟64 0 :* subst (𝓈₂ ⧺ intrSubst ρₑ) e
            None → bvsubst 𝓈₂ $ natΩ64 $ intΩ64 (ρ + 𝓍) + ι₁
      gs = dict
        [ mapOn gs₁ $ \ (ρₑ :* e) → 𝕟64 0 :* subst (𝓈₂ ⧺ intrSubst ρₑ) e
        , gs₂
        ]
  in Subst ρ vs ι gs

instance Null (Subst a) where null = nullSubst
instance (HasSubst a) ⇒ Append (Subst a) where (⧺) = appendSubst
instance (HasSubst a) ⇒ Monoid (Subst a)

prandVar ∷ ℕ64 → ℕ64 → State RG ℕ64
prandVar nˢ nᵇ = prandr (𝕟64 0) $ nᵇ + nˢ

prandSubst ∷ (Rand a) ⇒ ℕ64 → ℕ64 → State RG (Subst a)
prandSubst nˢ nᵈ = do
  ρ ← prandr zero nˢ
  vsSize ← prandr zero nˢ
  ι ← prandr (neg $ intΩ64 vsSize) $ intΩ64 nˢ
  vs ← mapMOn (vecF vsSize id) $ const $ prandChoice (const ∘ flip prandVar zero) prand nˢ nᵈ
  return $ Subst ρ vs ι null

instance (Rand a) ⇒  Rand (Subst a) where prand = prandSubst

nvsubst ∷ Subst a → 𝕏 → 𝑂 (ℕ64 ∧ a)
nvsubst (Subst _ρ _vs _ι gs) 𝓍 = gs ⋕? 𝓍

-- subst(ρ,vs,ι)(𝓍) =
--   𝓍      if  𝓍 < ρ
--   vs(𝓍)  if  𝓍 ≥ ρ  ∧  𝓍 - ρ < |vs|
--   𝓍+ι    if  𝓍 ≥ ρ  ∧  𝓍 - ρ ≥ |vs|
bvsubst ∷ Subst a → ℕ64 → ℕ64 ∨ (ℕ64 ∧ a)
bvsubst (Subst ρ vs ι _gs) 𝓍 =
  if | 𝓍 < ρ → Inl 𝓍
     -- 𝓍 ≥ ρ
     | 𝓍 - ρ < csize vs → vs ⋕! (𝓍 - ρ)
     -- 𝓍 ≥ ρ 
     -- 𝓍 - ρ < |vs|
     | otherwise → Inl $ natΩ64 $ intΩ64 𝓍 + ι

vsubst ∷ Subst a → 𝕐 → 𝕐 ∨ (ℕ64 ∧ a)
vsubst 𝓈 = \case
  NamedVar 𝓍 → elim𝑂 (Inl $ NamedVar 𝓍) Inr $ nvsubst 𝓈 𝓍
  BoundVar 𝓍 → mapInl BoundVar $ bvsubst 𝓈 𝓍

--------------
-- FOR ULCD --
--------------

substULCD ∷ Subst (ULCDExp 𝒸) → ULCDExp 𝒸 → ULCDExp 𝒸
substULCD 𝓈 (ULCDExp (𝐴 𝒸 e₀)) = case e₀ of
  Var_ULCD x → case bvsubst 𝓈 x of
    Inl x' → ULCDExp $ 𝐴 𝒸 $ Var_ULCD x'
    Inr (𝓃 :* e) → substULCD (intrSubst 𝓃) e
  Lam_ULCD e → ULCDExp $ 𝐴 𝒸 $ Lam_ULCD $ substULCD (shftSubst 1 𝓈) e
  App_ULCD e₁ e₂ → ULCDExp $ 𝐴 𝒸 $ App_ULCD (substULCD 𝓈 e₁) $ substULCD 𝓈 e₂

instance HasSubst (ULCDExp 𝒸) where subst = substULCD

prandULCDExp ∷ ℕ64 → ℕ64 → ℕ64 → State RG ULCDExpR
prandULCDExp nˢ nᵇ nᵈ = ULCDExp ∘ 𝐴 () ^$ mjoin $ prwchoose
    [ (𝕟64 2 :*) $ \ () → do
        Var_ULCD ^$ prandVar nˢ nᵇ
    , (nᵈ :*) $ \ () → do
        Lam_ULCD ^$ prandULCDExp nˢ (nᵇ+one) $ nᵈ-one
    , (nᵈ :*) $ \ () → do
        e₁ ← prandULCDExp nˢ nᵇ $ nᵈ-one
        e₂ ← prandULCDExp nˢ nᵇ $ nᵈ-one
        return $ App_ULCD e₁ e₂
    ]

instance Rand ULCDExpR where prand = flip prandULCDExp zero

-----------
-- TESTS --
-----------

-- basic --

𝔱 "subst:id" [| subst nullSubst [ulcd| λ → 0   |] |] [| [ulcd| λ → 0   |] |]
𝔱 "subst:id" [| subst nullSubst [ulcd| λ → 1   |] |] [| [ulcd| λ → 1   |] |]
𝔱 "subst:id" [| subst nullSubst [ulcd| λ → 2   |] |] [| [ulcd| λ → 2   |] |]
𝔱 "subst:id" [| subst nullSubst [ulcd| λ → 0 2 |] |] [| [ulcd| λ → 0 2 |] |]

𝔱 "subst:intro" [| subst (intrSubst one) [ulcd| λ → 0   |] |] [| [ulcd| λ → 0   |] |]
𝔱 "subst:intro" [| subst (intrSubst one) [ulcd| λ → 1   |] |] [| [ulcd| λ → 2   |] |]
𝔱 "subst:intro" [| subst (intrSubst one) [ulcd| λ → 2   |] |] [| [ulcd| λ → 3   |] |]
𝔱 "subst:intro" [| subst (intrSubst one) [ulcd| λ → 0 2 |] |] [| [ulcd| λ → 0 3 |] |]

𝔱 "subst:intro" [| subst (intrSubst $ 𝕟64 2) [ulcd| λ → 0   |] |] [| [ulcd| λ → 0   |] |]
𝔱 "subst:intro" [| subst (intrSubst $ 𝕟64 2) [ulcd| λ → 1   |] |] [| [ulcd| λ → 3   |] |]
𝔱 "subst:intro" [| subst (intrSubst $ 𝕟64 2) [ulcd| λ → 2   |] |] [| [ulcd| λ → 4   |] |]
𝔱 "subst:intro" [| subst (intrSubst $ 𝕟64 2) [ulcd| λ → 0 2 |] |] [| [ulcd| λ → 0 4 |] |]

𝔱 "subst:bind" [| subst (bindSubst [ulcd| λ → 0 |]) [ulcd| λ → 0 |] |] 
               [| [ulcd| λ → 0 |] |]
𝔱 "subst:bind" [| subst (bindSubst [ulcd| λ → 1 |]) [ulcd| λ → 0 |] |] 
               [| [ulcd| λ → 0 |] |]
𝔱 "subst:bind" [| subst (bindSubst [ulcd| λ → 0 |]) [ulcd| λ → 1 |] |] 
               [| [ulcd| λ → λ → 0 |] |]
𝔱 "subst:bind" [| subst (bindSubst [ulcd| λ → 1 |]) [ulcd| λ → 1 |] |] 
               [| [ulcd| λ → λ → 2 |] |]

𝔱 "subst:shftSubst" [| subst (shftSubst one $ bindSubst [ulcd| λ → 0 |]) [ulcd| λ → 0 |] |] 
                  [| [ulcd| λ → 0 |] |]
𝔱 "subst:shftSubst" [| subst (shftSubst one $ bindSubst [ulcd| λ → 1 |]) [ulcd| λ → 0 |] |] 
                  [| [ulcd| λ → 0 |] |]
𝔱 "subst:shftSubst" [| subst (shftSubst one $ bindSubst [ulcd| λ → 0 |]) [ulcd| λ → 1 |] |] 
                  [| [ulcd| λ → 1 |] |]
𝔱 "subst:shftSubst" [| subst (shftSubst one $ bindSubst [ulcd| λ → 1 |]) [ulcd| λ → 1 |] |] 
                  [| [ulcd| λ → 1 |] |]
𝔱 "subst:shftSubst" [| subst (shftSubst one $ bindSubst [ulcd| λ → 2 |]) [ulcd| λ → 0 |] |] 
                  [| [ulcd| λ → 0 |] |]
𝔱 "subst:shftSubst" [| subst (shftSubst one $ bindSubst [ulcd| λ → 2 |]) [ulcd| λ → 1 |] |] 
                  [| [ulcd| λ → 1 |] |]
𝔱 "subst:shftSubst" [| subst (shftSubst one $ bindSubst [ulcd| λ → 1 |]) [ulcd| λ → 2 |] |] 
                  [| [ulcd| λ → λ → 3 |] |]
𝔱 "subst:shftSubst" [| subst (shftSubst one $ bindSubst [ulcd| λ → 2 |]) [ulcd| λ → 2 |] |] 
                  [| [ulcd| λ → λ → 4 |] |]

-- append --

𝔱 "subst:⧺" [| subst null                   [ulcd| λ → 0 |] |] [| [ulcd| λ → 0 |] |]
𝔱 "subst:⧺" [| subst (null ⧺ null)          [ulcd| λ → 0 |] |] [| [ulcd| λ → 0 |] |]
𝔱 "subst:⧺" [| subst (shftSubst one null)     [ulcd| λ → 0 |] |] [| [ulcd| λ → 0 |] |]
𝔱 "subst:⧺" [| subst (shftSubst (𝕟64 2) null) [ulcd| λ → 0 |] |] [| [ulcd| λ → 0 |] |]

𝔱 "subst:⧺" [| subst null          [ulcd| λ → 1 |] |] [| [ulcd| λ → 1 |] |]
𝔱 "subst:⧺" [| subst (null ⧺ null) [ulcd| λ → 1 |] |] [| [ulcd| λ → 1 |] |]

𝔱 "subst:⧺" [| subst (intrSubst one)               [ulcd| λ → 0 |] |] [| [ulcd| λ → 0 |] |]
𝔱 "subst:⧺" [| subst (null ⧺ intrSubst one ⧺ null) [ulcd| λ → 0 |] |] [| [ulcd| λ → 0 |] |]

𝔱 "subst:⧺" [| subst (intrSubst one)               [ulcd| λ → 1 |] |] [| [ulcd| λ → 2 |] |]
𝔱 "subst:⧺" [| subst (null ⧺ intrSubst one ⧺ null) [ulcd| λ → 1 |] |] [| [ulcd| λ → 2 |] |]

𝔱 "subst:⧺" 
  [| subst (bindSubst [ulcd| λ → 0 |])               [ulcd| λ → 1 |] |] [| [ulcd| λ → λ → 0 |] |]
𝔱 "subst:⧺" 
  [| subst (null ⧺ bindSubst [ulcd| λ → 0 |] ⧺ null) [ulcd| λ → 1 |] |] [| [ulcd| λ → λ → 0 |] |]

𝔱 "subst:⧺" [| subst (intrSubst $ 𝕟64 2)              [ulcd| λ → 1 |] |] [| [ulcd| λ → 3 |] |]
𝔱 "subst:⧺" [| subst (intrSubst one ⧺ intrSubst one) [ulcd| λ → 1 |] |] [| [ulcd| λ → 3 |] |]

𝔱 "subst:⧺" 
  [| subst (bindSubst [ulcd| λ → 0 |]) [ulcd| λ → 1 |] |] 
  [| [ulcd| λ → λ → 0 |] |]
𝔱 "subst:⧺" 
  [| subst (shftSubst one (bindSubst [ulcd| λ → 0 |]) ⧺ intrSubst one) [ulcd| λ → 1 |] |] 
  [| [ulcd| λ → λ → 0 |] |]

𝔱 "subst:⧺" 
  [| subst (intrSubst one ⧺ bindSubst [ulcd| 1 |]) [ulcd| 0 (λ → 2) |] |] 
  [| [ulcd| 2 (λ → 2) |] |]
𝔱 "subst:⧺" 
  [| subst (shftSubst one (bindSubst [ulcd| 1 |]) ⧺ intrSubst one) [ulcd| 0 (λ → 2) |] |] 
  [| [ulcd| 2 (λ → 2) |] |]

𝔱 "subst:⧺"
  [| subst (intrSubst one) (subst (shftSubst one nullSubst) [ulcd| 0 |]) |]
  [| subst (intrSubst one ⧺ shftSubst one nullSubst) [ulcd| 0 |] |]

𝔱 "subst:⧺"
  [| subst (bindSubst [ulcd| 1 |]) (subst (shftSubst one (intrSubst one)) [ulcd| 0 |]) |]
  [| subst (bindSubst [ulcd| 1 |] ⧺ shftSubst one (intrSubst one)) [ulcd| 0 |] |]

𝔱 "subst:⧺"
  [| subst (shftSubst one (bindSubst [ulcd| 1 |])) (subst (shftSubst one nullSubst) [ulcd| 1 |]) |]
  [| subst (shftSubst one (bindSubst [ulcd| 1 |]) ⧺ shftSubst one nullSubst) [ulcd| 1 |] |]

-- fuzzing --

𝔣 "zzz:subst:wf" (𝕟64 100) [| randSml @ (Subst ULCDExpR) |] [| wfSubst |]

𝔣 "zzz:subst:⧺:wf" (𝕟64 100) 
  [| do 𝓈₁ ← randSml @ (Subst ULCDExpR)
        𝓈₂ ← randSml @ (Subst ULCDExpR)
        return $ 𝓈₁ :* 𝓈₂
  |]
  [| \ (𝓈₁ :* 𝓈₂) → wfSubst (𝓈₁ ⧺ 𝓈₂) |]

𝔣 "zzz:subst:refl:hom" (𝕟64 100) 
  [| do e ← randSml @ ULCDExpR
        return $ e
  |]
  [| \ e → 
       subst nullSubst e ≡ e
  |]

𝔣 "zzz:subst:refl/wk:hom" (𝕟64 100)
  [| do n ← randSml @ ℕ64
        e ← randSml @ ULCDExpR
        return $ n :* e
  |]
  [| \ (n :* e) → subst (shftSubst n nullSubst) e ≡ e 
  |]

𝔣 "zzz:subst:bind" (𝕟64 100)
  [| do e₁ ← randSml @ ULCDExpR
        e₂ ← randSml @ ULCDExpR
        return $ e₁ :* e₂
  |]
  [| \ (e₁ :* e₂) → 
       subst (bindSubst e₁ ⧺ intrSubst one) e₂ 
       ≡ 
       e₂
  |]

𝔣 "zzz:subst:commute" (𝕟64 100)
  [| do e₁ ← randSml @ ULCDExpR
        e₂ ← randSml @ ULCDExpR
        return $ e₁ :* e₂
  |]
  [| \ (e₁ :* e₂) → 
       subst (intrSubst one ⧺ bindSubst e₁) e₂
       ≡ 
       subst (shftSubst one (bindSubst e₁) ⧺ intrSubst one) e₂
  |]


𝔣 "zzz:subst:⧺:hom" (𝕟64 100) 
  [| do 𝓈₁ ← randSml @ (Subst ULCDExpR)
        𝓈₂ ← randSml @ (Subst ULCDExpR)
        e ← randSml @ ULCDExpR
        return $ 𝓈₁ :* 𝓈₂ :* e
  |]
  [| \ (𝓈₁ :* 𝓈₂ :* e) → 
       subst (𝓈₁ ⧺ 𝓈₂) e ≡ subst 𝓈₁ (subst 𝓈₂ e)
  |]

𝔣 "zzz:subst:⧺:lrefl" (𝕟64 100) 
  [| do 𝓈 ← randSml @ (Subst ULCDExpR)
        e ← randSml @ ULCDExpR
        return $ 𝓈 :* e
  |]
  [| \ (𝓈 :* e) → 
       subst (nullSubst ⧺ 𝓈) e ≡ subst 𝓈 e
  |]

𝔣 "zzz:subst:⧺:rrefl" (𝕟64 100) 
  [| do 𝓈 ← randSml @ (Subst ULCDExpR)
        e ← randSml @ ULCDExpR
        return $ 𝓈 :* e
  |]
  [| \ (𝓈 :* e) → 
       subst (𝓈 ⧺ nullSubst) e ≡ subst 𝓈 e
  |]

𝔣 "zzz:subst:⧺:lrefl/wk" (𝕟64 100)
  [| do n ← randSml @ ℕ64
        𝓈 ← randSml @ (Subst ULCDExpR)
        e ← randSml @ ULCDExpR
        return $ n :* 𝓈 :* e
  |]
  [| \ (n :* 𝓈 :* e) → subst (shftSubst n nullSubst ⧺ 𝓈) e ≡ subst 𝓈 e 
  |]

𝔣 "zzz:subst:⧺:rrefl/wk" (𝕟64 100)
  [| do n ← randSml @ ℕ64
        𝓈 ← randSml @ (Subst ULCDExpR)
        e ← randSml @ ULCDExpR
        return $ n :* 𝓈 :* e
  |]
  [| \ (n :* 𝓈 :* e) → subst (𝓈 ⧺ shftSubst n nullSubst) e ≡ subst 𝓈 e 
  |]

𝔣 "zzz:subst:⧺:trans" (𝕟64 100) 
  [| do 𝓈₁ ← randSml @ (Subst ULCDExpR)
        𝓈₂ ← randSml @ (Subst ULCDExpR)
        𝓈₃ ← randSml @ (Subst ULCDExpR)
        e ← randSml @ ULCDExpR
        return $ 𝓈₁ :* 𝓈₂ :* 𝓈₃ :* e
  |]
  [| \ (𝓈₁ :* 𝓈₂ :* 𝓈₃ :* e) → 
       subst ((𝓈₁ ⧺ 𝓈₂) ⧺ 𝓈₃) e ≡ subst (𝓈₁ ⧺ (𝓈₂ ⧺ 𝓈₃)) e 
  |]

buildTests
