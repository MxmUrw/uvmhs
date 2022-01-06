module UVMHS.Lib.Substitution where

import UVMHS.Core
import UVMHS.Lib.Pretty
import UVMHS.Lib.Testing
import UVMHS.Lib.Annotated
import UVMHS.Lib.Rand
import UVMHS.Lib.Variables
import UVMHS.Lang.ULCD

class Substy t where
  𝓈var ∷ t a → 𝕐 → 𝕐 ∨ (𝑂 (t Void) ∧ a)
  𝓈shift ∷ ℕ64 → t a → t a
  𝓈combine ∷ (Monad m) ⇒ (t a → b → m a) → t a → t b → m (t a)

class Substable m e a | a → e where
  gsubst ∷ (Substy t,Monad m) ⇒ (b → m e) → t b → a → m a

subst ∷ (Substy t,Substable ID a a) ⇒ t a → a → a
subst = unID ∘∘ gsubst ID

(⋈) ∷ (Substy t,Substable m a a,Monad m) ⇒ t a → t a → m (t a)
(⋈) = 𝓈combine $ gsubst return

---------------
-- Variables --
---------------

grename ∷ (Substy t,Monad m) ⇒ (a → m 𝕐) → t a → 𝕐 → m 𝕐
grename 𝓋 𝓈 𝓎 = case 𝓈var 𝓈 𝓎 of
  Inl 𝓎' → return 𝓎'
  Inr (𝓈O :* e) → elim𝑂 return (grename exfalso) 𝓈O *$ 𝓋 e

instance Substable m 𝕐 𝕐 where gsubst = grename

prandNVar ∷ ℕ64 → State RG 𝕏
prandNVar nˢ = 𝕏 "x" ∘ Some ^$ prandr 0 nˢ

prandBVar ∷ ℕ64 → ℕ64 → State RG ℕ64
prandBVar nˢ nᵇ = prandr 0 $ nᵇ + nˢ

prandVar ∷ ℕ64 → ℕ64 → State RG 𝕐
prandVar nˢ nᵇ = mjoin $ prchoose
  [ \ () → NamedVar ^$ prandNVar nˢ
  , \ () → BoundVar ^$ prandBVar nˢ nᵇ
  ]

---------------------------
-- UNSCOPED SUBSTITUTION --
---------------------------

newtype USubst a = USubst { unUSubst ∷ 𝕏 ⇰ a }
  deriving (Eq,Ord,Show,Pretty)

𝓈ubind ∷ 𝕏 ⇰ a → USubst a
𝓈ubind = USubst

𝓈varUSubst ∷ USubst a → 𝕐 → 𝕐 ∨ a
𝓈varUSubst 𝓈 𝓎 = case 𝓎 of
  NamedVar 𝓍 | Some v ← unUSubst 𝓈 ⋕? 𝓍 → Inr v
  _ → Inl 𝓎

nullUSubst ∷ USubst a
nullUSubst = USubst dø

𝓈combineUSubst ∷ (Monad m) ⇒ (USubst a → b → m a) → USubst a → USubst b → m (USubst a)
𝓈combineUSubst sub 𝓈₂ 𝓈₁ = USubst ∘ dict ^$ exchange
  [ mapM (sub 𝓈₂) $ unUSubst 𝓈₁
  , return $ unUSubst 𝓈₂
  ]

appendUSubst ∷ (Substable ID a a) ⇒ USubst a → USubst a → USubst a
appendUSubst = unID ∘∘ 𝓈combineUSubst (gsubst ID)

instance Substy USubst where
  𝓈var 𝓈 = mapInr (None :*) ∘ 𝓈varUSubst 𝓈
  𝓈shift = const id
  𝓈combine = 𝓈combineUSubst

usubst ∷ (Substable ID a a) ⇒ USubst a → a → a
usubst = subst

instance Null (USubst a) where null = USubst dø
instance (Substable ID a a) ⇒ Append (USubst a) where (⧺) = unID ∘∘ (⋈)
instance (Substable ID a a) ⇒ Monoid (USubst a)

prandUSubst ∷ (Rand a) ⇒ ℕ64 → ℕ64 → State RG (USubst a)
prandUSubst nˢ nᵈ = USubst ∘ dict ^$ mapMOn (upTo nˢ) $ const $ do
  x ← prandNVar nˢ
  v ← prand nˢ nᵈ
  return $ x ↦ v

instance (Rand a) ⇒  Rand (USubst a) where prand = prandUSubst

-------------------------
-- SCOPED SUBSTITUTION --
-------------------------

data SSubst a = SSubst
  { substShft ∷ ℕ64
  , substIncr ∷ ℤ64
  --               variable    term
  --               ↓↓↓         ↓
  , substByvs ∷ 𝕍 (ℕ64 ∨ ℕ64 ∧ a)
  --                     ↑↑↑↑
  --                     shifted
  --                       term
  --                       ↓
  , substNyvs ∷ 𝕏 ⇰ (ℕ64 ∧ a)
  --                 ↑↑↑
  --                 shifted
  } deriving (Eq,Ord,Show)
makePrettyRecord ''SSubst

𝓈nvarSSubst ∷ SSubst a → 𝕏 → 𝑂 (ℕ64 ∧ a)
𝓈nvarSSubst (SSubst _ρ _ι _bvs nvs) 𝓍 = nvs ⋕? 𝓍

-- subst(ρ,ι,bvs,nvs)(𝓎) =
--   𝓎       if  𝓎 bound  and  𝓎 < ρ
--   𝓎+ι     if  𝓎 bound  and  𝓎 ≥ ρ  and  𝓎 - ρ ≥ |vs|
--   bvs(𝓎)  if  𝓎 bound  and  𝓎 ≥ ρ  and  𝓎 - ρ < |vs|
--   nvs(𝓎)  if  𝓎 named
𝓈bvarSSubst ∷ SSubst a → ℕ64 → ℕ64 ∨ (ℕ64 ∧ a)
𝓈bvarSSubst (SSubst ρ ι bvs _nvs) 𝓍 =
  if | 𝓍 < ρ → Inl 𝓍
     -- 𝓍 ≥ ρ
     | 𝓍 - ρ < csize bvs → bvs ⋕! (𝓍 - ρ)
     -- 𝓍 ≥ ρ 
     -- 𝓍 - ρ < |bvs|
     | otherwise → Inl $ natΩ64 $ intΩ64 𝓍 + ι

𝓈varSSubst ∷ SSubst a → 𝕐 → 𝕐 ∨ (ℕ64 ∧ a)
𝓈varSSubst 𝓈 = \case
  NamedVar 𝓍 → elim𝑂 (Inl $ NamedVar 𝓍) Inr $ 𝓈nvarSSubst 𝓈 𝓍
  BoundVar 𝓍 → mapInl BoundVar $ 𝓈bvarSSubst 𝓈 𝓍

wfSSubst ∷ SSubst a → 𝔹
wfSSubst (SSubst _ρ ι bvs _nvs) = and
  -- `|vs| + ι` should be non-negative
  [ intΩ64 (csize bvs) + ι ≥ 0
  ]

-- subst(id)(𝓍) = 𝓍
-- id ≜ (0,∅,0)
nullSSubst ∷ SSubst a
nullSSubst = SSubst
  { substShft = 0
  , substIncr = 0
  , substByvs = vec []
  , substNyvs = dø
  }

-- subst(intro)(𝓍) = 𝓍+1
-- intro ≜ (0,∅,1)
𝓈intro ∷ ℕ64 → SSubst a
𝓈intro n = SSubst
  { substShft = 0
  , substIncr = intΩ64 n
  , substByvs = vec []
  , substNyvs = dø
  }

-- subst(𝓈shiftSSubst[n](ρ,vs,ι))(𝓍) = subst(ρ,vs,ι)(𝓍+n)
-- 𝓈shiftSSubst[n](ρ,vs,ι) ≜ (ρ′,vs′,ι)
--   where
--     ρ′ = ρ+n
--     vs′(n′) = 
--       𝓍+n       if  vs(n′) = 𝓍
--       (ρₑ+n,e)  if  vs(n′) = (ρₑ,e)
𝓈shiftSSubst ∷ ℕ64 → SSubst a → SSubst a
𝓈shiftSSubst n (SSubst ρ ι bvs nvs) = 
  let ρ' = ρ + n
      bvs' = mapOn bvs $ \case
        Inl 𝓍 → Inl $ 𝓍 + n
        Inr (ρₑ :* e) → Inr $ (ρₑ + n) :* e
      nvs' = mapOn nvs $ \ (ρₑ :* e) → (ρₑ + n) :* e
  in SSubst ρ' ι bvs' nvs'

-- subst(bind(v))(𝓍) =
--   v    if  𝓍 = 0
--   𝓍-1  if  𝓍 > 0
-- bind(v) ≜ (0,{0↦v},-1)
𝓈bbind ∷ a → SSubst a
𝓈bbind v = SSubst
  { substShft = 0
  , substIncr = neg 1
  , substByvs = vec [Inr $ 0 :* v]
  , substNyvs = dø
  }

𝓈nbind ∷ 𝕏 ⇰ a → SSubst a
𝓈nbind xes = SSubst
  { substShft = 0
  , substIncr = 0
  , substByvs = vec []
  , substNyvs = map (0 :*) xes
  }

𝓈combineSSubst ∷ (Monad m) ⇒ (SSubst a → b → m a) → SSubst a → SSubst b → m (SSubst a)
𝓈combineSSubst sub 𝓈₂@(SSubst ρ₂ ι₂ bvs₂ nvs₂) (SSubst ρ₁ ι₁ bvs₁ nvs₁) = do
  let ρ = ρ₁ ⊓ ρ₂
      logicalSize = natΩ64 $ joins
        [ intΩ64 $ csize bvs₁ + ρ₁
        , intΩ64 (csize bvs₂) + intΩ64 ρ₂ - ι₁
        ]
      vsSize = logicalSize - ρ
      vsOffset₁ = ρ₁ - ρ
      ι = ι₁ + ι₂
  bvs ← exchange $ vecF vsSize $ \ 𝓍 → 
        if 𝓍 < vsOffset₁
        then return $ 𝓈bvarSSubst 𝓈₂ $ ρ + 𝓍
        else
          case bvs₁ ⋕? (𝓍 - vsOffset₁) of
            Some v → case v of
              Inl 𝓍' → return $ 𝓈bvarSSubst 𝓈₂ 𝓍'
              Inr (ρₑ :* e) → do
                𝓈 ← 𝓈combineSSubst sub 𝓈₂ $ 𝓈intro ρₑ
                Inr ∘ (0 :*) ^$ sub 𝓈 e
            None → return $ 𝓈bvarSSubst 𝓈₂ $ natΩ64 $ intΩ64 (ρ + 𝓍) + ι₁
  nvs ← dict ^$ exchange
    [ mapMOn nvs₁ $ \ (ρₑ :* e) → do
        𝓈 ← 𝓈combineSSubst sub 𝓈₂ $ 𝓈intro ρₑ
        (0 :*) ^$ sub 𝓈 e
    , return nvs₂
    ]
  return $ SSubst ρ ι bvs nvs

appendSubst ∷ (Substable ID a a) ⇒ SSubst a → SSubst a → SSubst a
appendSubst = unID ∘∘ 𝓈combineSSubst (gsubst ID)

instance Substy SSubst where
  𝓈var 𝓈 = mapInr (mapFst $ Some ∘ 𝓈intro) ∘ 𝓈varSSubst 𝓈
  𝓈shift = 𝓈shiftSSubst
  𝓈combine = 𝓈combineSSubst

ssubst ∷ (Substable ID a a) ⇒ SSubst a → a → a
ssubst = subst

instance Null (SSubst a) where null = nullSSubst
instance (Substable ID a a) ⇒ Append (SSubst a) where (⧺) = unID ∘∘ (⋈)
instance (Substable ID a a) ⇒ Monoid (SSubst a)

prandSSubst ∷ (Rand a) ⇒ ℕ64 → ℕ64 → State RG (SSubst a)
prandSSubst nˢ nᵈ = do
  ρ ← prandr zero nˢ
  vsSize ← prandr zero nˢ
  ι ← prandr (neg $ intΩ64 vsSize) $ intΩ64 nˢ
  bvs ← mapMOn (vecF vsSize id) $ const $ prandChoice (const ∘ flip prandBVar zero) prand nˢ nᵈ
  nvs ← dict ^$ mapMOn (upTo nˢ) $ const $ do
    x ← prandNVar nˢ
    v ← prand nˢ nᵈ
    return $ x ↦ v
  return $ SSubst ρ ι bvs nvs

instance (Rand a) ⇒  Rand (SSubst a) where prand = prandSSubst

--------------
-- FOR ULCD --
--------------

gsubstULCD ∷ ∀ t m a 𝒸. (Substy t,Monad m) ⇒ (a → m (ULCDExp 𝒸)) → t a → ULCDExp 𝒸 → m (ULCDExp 𝒸)
gsubstULCD 𝓋 𝓈 (ULCDExp (𝐴 𝒸 e₀)) = case e₀ of
  Var_ULCD x → case 𝓈var 𝓈 x of
    Inl x' → return $ ULCDExp $ 𝐴 𝒸 $ Var_ULCD x'
    Inr (𝓈O :* e) → elim𝑂 return (gsubstULCD exfalso) 𝓈O *$ 𝓋 e
  Lam_ULCD e → do
    e' ← gsubstULCD 𝓋 (𝓈shift 1 𝓈) e
    return $ ULCDExp $ 𝐴 𝒸 $ Lam_ULCD e'
  App_ULCD e₁ e₂ → do
    e₁' ← gsubstULCD 𝓋 𝓈 e₁
    e₂' ← gsubstULCD 𝓋 𝓈 e₂
    return $ ULCDExp $ 𝐴 𝒸 $ App_ULCD e₁' e₂'

instance Substable m (ULCDExp 𝒸) (ULCDExp 𝒸) where gsubst = gsubstULCD

prandULCDExp ∷ ℕ64 → ℕ64 → ℕ64 → State RG ULCDExpR
prandULCDExp nˢ nᵇ nᵈ = ULCDExp ∘ 𝐴 () ^$ mjoin $ prwchoose
    [ (2 :*) $ \ () → do
        Var_ULCD ^$ prandVar nˢ nᵇ
    , (nᵈ :*) $ \ () → do
        Lam_ULCD ^$ prandULCDExp nˢ (nᵇ + 1) $ nᵈ - 1
    , (nᵈ :*) $ \ () → do
        e₁ ← prandULCDExp nˢ nᵇ $ nᵈ - 1
        e₂ ← prandULCDExp nˢ nᵇ $ nᵈ - 1
        return $ App_ULCD e₁ e₂
    ]

instance Rand ULCDExpR where prand = flip prandULCDExp zero

-----------
-- TESTS --
-----------

-- basic --

𝔱 "ssubst:id" [| ssubst null [ulcd| λ → 0   |] |] [| [ulcd| λ → 0   |] |]
𝔱 "ssubst:id" [| ssubst null [ulcd| λ → 1   |] |] [| [ulcd| λ → 1   |] |]
𝔱 "ssubst:id" [| ssubst null [ulcd| λ → 2   |] |] [| [ulcd| λ → 2   |] |]
𝔱 "ssubst:id" [| ssubst null [ulcd| λ → 0 2 |] |] [| [ulcd| λ → 0 2 |] |]

𝔱 "ssubst:intro" [| ssubst (𝓈intro 1) [ulcd| λ → 0   |] |] [| [ulcd| λ → 0   |] |]
𝔱 "ssubst:intro" [| ssubst (𝓈intro 1) [ulcd| λ → 1   |] |] [| [ulcd| λ → 2   |] |]
𝔱 "ssubst:intro" [| ssubst (𝓈intro 1) [ulcd| λ → 2   |] |] [| [ulcd| λ → 3   |] |]
𝔱 "ssubst:intro" [| ssubst (𝓈intro 1) [ulcd| λ → 0 2 |] |] [| [ulcd| λ → 0 3 |] |]

𝔱 "ssubst:intro" [| ssubst (𝓈intro 2) [ulcd| λ → 0   |] |] [| [ulcd| λ → 0   |] |]
𝔱 "ssubst:intro" [| ssubst (𝓈intro 2) [ulcd| λ → 1   |] |] [| [ulcd| λ → 3   |] |]
𝔱 "ssubst:intro" [| ssubst (𝓈intro 2) [ulcd| λ → 2   |] |] [| [ulcd| λ → 4   |] |]
𝔱 "ssubst:intro" [| ssubst (𝓈intro 2) [ulcd| λ → 0 2 |] |] [| [ulcd| λ → 0 4 |] |]

𝔱 "ssubst:bind" [| subst (𝓈bbind [ulcd| λ → 0 |]) [ulcd| λ → 0 |] |] [| [ulcd| λ → 0     |] |]
𝔱 "ssubst:bind" [| subst (𝓈bbind [ulcd| λ → 1 |]) [ulcd| λ → 0 |] |] [| [ulcd| λ → 0     |] |]
𝔱 "ssubst:bind" [| subst (𝓈bbind [ulcd| λ → 0 |]) [ulcd| λ → 1 |] |] [| [ulcd| λ → λ → 0 |] |]
𝔱 "ssubst:bind" [| subst (𝓈bbind [ulcd| λ → 1 |]) [ulcd| λ → 1 |] |] [| [ulcd| λ → λ → 2 |] |]

𝔱 "ssubst:shift" [| subst (𝓈shift 1 $ 𝓈bbind [ulcd| λ → 0 |]) [ulcd| λ → 0 |] |] 
                 [| [ulcd| λ → 0 |] |]
𝔱 "ssubst:shift" [| subst (𝓈shift 1 $ 𝓈bbind [ulcd| λ → 1 |]) [ulcd| λ → 0 |] |] 
                 [| [ulcd| λ → 0 |] |]
𝔱 "ssubst:shift" [| subst (𝓈shift 1 $ 𝓈bbind [ulcd| λ → 0 |]) [ulcd| λ → 1 |] |] 
                 [| [ulcd| λ → 1 |] |]
𝔱 "ssubst:shift" [| subst (𝓈shift 1 $ 𝓈bbind [ulcd| λ → 1 |]) [ulcd| λ → 1 |] |] 
                 [| [ulcd| λ → 1 |] |]
𝔱 "ssubst:shift" [| subst (𝓈shift 1 $ 𝓈bbind [ulcd| λ → 2 |]) [ulcd| λ → 0 |] |] 
                 [| [ulcd| λ → 0 |] |]
𝔱 "ssubst:shift" [| subst (𝓈shift 1 $ 𝓈bbind [ulcd| λ → 2 |]) [ulcd| λ → 1 |] |] 
                 [| [ulcd| λ → 1 |] |]
𝔱 "ssubst:shift" [| subst (𝓈shift 1 $ 𝓈bbind [ulcd| λ → 1 |]) [ulcd| λ → 2 |] |] 
                 [| [ulcd| λ → λ → 3 |] |]
𝔱 "ssubst:shift" [| subst (𝓈shift 1 $ 𝓈bbind [ulcd| λ → 2 |]) [ulcd| λ → 2 |] |] 
                 [| [ulcd| λ → λ → 4 |] |]

-- append --

𝔱 "ssubst:⧺" [| ssubst null            [ulcd| λ → 0 |] |] [| [ulcd| λ → 0 |] |]
𝔱 "ssubst:⧺" [| ssubst (null ⧺ null)   [ulcd| λ → 0 |] |] [| [ulcd| λ → 0 |] |]
𝔱 "ssubst:⧺" [| ssubst (𝓈shift 1 null) [ulcd| λ → 0 |] |] [| [ulcd| λ → 0 |] |]
𝔱 "ssubst:⧺" [| ssubst (𝓈shift 2 null) [ulcd| λ → 0 |] |] [| [ulcd| λ → 0 |] |]

𝔱 "ssubst:⧺" [| ssubst null          [ulcd| λ → 1 |] |] [| [ulcd| λ → 1 |] |]
𝔱 "ssubst:⧺" [| ssubst (null ⧺ null) [ulcd| λ → 1 |] |] [| [ulcd| λ → 1 |] |]

𝔱 "ssubst:⧺" [| ssubst (𝓈intro 1)               [ulcd| λ → 0 |] |] [| [ulcd| λ → 0 |] |]
𝔱 "ssubst:⧺" [| ssubst (null ⧺ 𝓈intro 1 ⧺ null) [ulcd| λ → 0 |] |] [| [ulcd| λ → 0 |] |]

𝔱 "ssubst:⧺" [| ssubst (𝓈intro 1)               [ulcd| λ → 1 |] |] [| [ulcd| λ → 2 |] |]
𝔱 "ssubst:⧺" [| ssubst (null ⧺ 𝓈intro 1 ⧺ null) [ulcd| λ → 1 |] |] [| [ulcd| λ → 2 |] |]

𝔱 "ssubst:⧺" [| ssubst (𝓈bbind [ulcd| λ → 0 |]) [ulcd| λ → 1 |] |] 
             [| [ulcd| λ → λ → 0 |] |]
𝔱 "ssubst:⧺" [| ssubst (null ⧺ 𝓈bbind [ulcd| λ → 0 |] ⧺ null) [ulcd| λ → 1 |] |] 
             [| [ulcd| λ → λ → 0 |] |]

𝔱 "ssubst:⧺" [| ssubst (𝓈intro 2) [ulcd| λ → 1 |] |]            [| [ulcd| λ → 3 |] |]
𝔱 "ssubst:⧺" [| ssubst (𝓈intro 1 ⧺ 𝓈intro 1) [ulcd| λ → 1 |] |] [| [ulcd| λ → 3 |] |]

𝔱 "ssubst:⧺" [| ssubst (𝓈bbind [ulcd| λ → 0 |]) [ulcd| λ → 1 |] |] 
             [| [ulcd| λ → λ → 0 |] |]
𝔱 "ssubst:⧺" [| ssubst (𝓈shift 1 (𝓈bbind [ulcd| λ → 0 |]) ⧺ 𝓈intro 1) [ulcd| λ → 1 |] |] 
             [| [ulcd| λ → λ → 0 |] |]

𝔱 "ssubst:⧺" [| ssubst (𝓈intro 1 ⧺ 𝓈bbind [ulcd| 1 |]) [ulcd| 0 (λ → 2) |] |] 
             [| [ulcd| 2 (λ → 2) |] |]
𝔱 "ssubst:⧺" [| ssubst (𝓈shift 1 (𝓈bbind [ulcd| 1 |]) ⧺ 𝓈intro 1) [ulcd| 0 (λ → 2) |] |] 
             [| [ulcd| 2 (λ → 2) |] |]

𝔱 "ssubst:⧺" [| ssubst (𝓈intro 1) (ssubst (𝓈shift 1 null) [ulcd| 0 |]) |]
             [| ssubst (𝓈intro 1 ⧺ 𝓈shift 1 null) [ulcd| 0 |] |]

𝔱 "ssubst:⧺" [| ssubst (𝓈bbind [ulcd| 1 |]) (ssubst (𝓈shift 1 (𝓈intro 1)) [ulcd| 0 |]) |]
             [| ssubst (𝓈bbind [ulcd| 1 |] ⧺ 𝓈shift 1 (𝓈intro 1)) [ulcd| 0 |] |]

𝔱 "ssubst:⧺" [| ssubst (𝓈shift 1 (𝓈bbind [ulcd| 1 |])) (ssubst (𝓈shift 1 null) [ulcd| 1 |]) |]
             [| ssubst (𝓈shift 1 (𝓈bbind [ulcd| 1 |]) ⧺ 𝓈shift 1 null) [ulcd| 1 |] |]

-- unscoped --

𝔱 "usubst:bind" [| usubst (𝓈ubind $ var "x" ↦ [ulcd| 0 |]) [ulcd| x     |] |] [| [ulcd| 0     |] |]
𝔱 "usubst:bind" [| usubst (𝓈ubind $ var "x" ↦ [ulcd| 0 |]) [ulcd| λ → x |] |] [| [ulcd| λ → 0 |] |]
𝔱 "ssubst:bind" [| ssubst (𝓈nbind $ var "x" ↦ [ulcd| 0 |]) [ulcd| λ → x |] |] [| [ulcd| λ → 1 |] |]

-- fuzzing --

𝔣 "zzz:ssubst:wf" 100 [| randSml @ (SSubst ULCDExpR) |] [| wfSSubst |]

𝔣 "zzz:ssubst:⧺:wf" 100 
  [| do 𝓈₁ ← randSml @ (SSubst ULCDExpR)
        𝓈₂ ← randSml @ (SSubst ULCDExpR)
        return $ 𝓈₁ :* 𝓈₂
  |]
  [| \ (𝓈₁ :* 𝓈₂) → wfSSubst (𝓈₁ ⧺ 𝓈₂) |]

𝔣 "zzz:ssubst:refl:hom" 100 
  [| do e ← randSml @ ULCDExpR
        return $ e
  |]
  [| \ e → 
       ssubst null e ≡ e
  |]

𝔣 "zzz:ssubst:refl/shift:hom" 100
  [| do n ← randSml @ ℕ64
        e ← randSml @ ULCDExpR
        return $ n :* e
  |]
  [| \ (n :* e) → ssubst (𝓈shift n null) e ≡ e 
  |]

𝔣 "zzz:ssubst:bind" 100
  [| do e₁ ← randSml @ ULCDExpR
        e₂ ← randSml @ ULCDExpR
        return $ e₁ :* e₂
  |]
  [| \ (e₁ :* e₂) → 
       ssubst (𝓈bbind e₁ ⧺ 𝓈intro 1) e₂ 
       ≡ 
       e₂
  |]

𝔣 "zzz:ssubst:commute" 100
  [| do e₁ ← randSml @ ULCDExpR
        e₂ ← randSml @ ULCDExpR
        return $ e₁ :* e₂
  |]
  [| \ (e₁ :* e₂) → 
       ssubst (𝓈intro 1 ⧺ 𝓈bbind e₁) e₂
       ≡ 
       ssubst (𝓈shift 1 (𝓈bbind e₁) ⧺ 𝓈intro 1) e₂
  |]


𝔣 "zzz:ssubst:⧺:hom" 100 
  [| do 𝓈₁ ← randSml @ (SSubst ULCDExpR)
        𝓈₂ ← randSml @ (SSubst ULCDExpR)
        e ← randSml @ ULCDExpR
        return $ 𝓈₁ :* 𝓈₂ :* e
  |]
  [| \ (𝓈₁ :* 𝓈₂ :* e) → 
       ssubst (𝓈₁ ⧺ 𝓈₂) e ≡ ssubst 𝓈₁ (ssubst 𝓈₂ e)
  |]

𝔣 "zzz:ssubst:⧺:lrefl" 100 
  [| do 𝓈 ← randSml @ (SSubst ULCDExpR)
        e ← randSml @ ULCDExpR
        return $ 𝓈 :* e
  |]
  [| \ (𝓈 :* e) → 
       ssubst (null ⧺ 𝓈) e ≡ ssubst 𝓈 e
  |]

𝔣 "zzz:ssubst:⧺:rrefl" 100 
  [| do 𝓈 ← randSml @ (SSubst ULCDExpR)
        e ← randSml @ ULCDExpR
        return $ 𝓈 :* e
  |]
  [| \ (𝓈 :* e) → 
       ssubst (𝓈 ⧺ null) e ≡ ssubst 𝓈 e
  |]

𝔣 "zzz:ssubst:⧺:lrefl/shift" 100
  [| do n ← randSml @ ℕ64
        𝓈 ← randSml @ (SSubst ULCDExpR)
        e ← randSml @ ULCDExpR
        return $ n :* 𝓈 :* e
  |]
  [| \ (n :* 𝓈 :* e) → ssubst (𝓈shift n null ⧺ 𝓈) e ≡ ssubst 𝓈 e 
  |]

𝔣 "zzz:ssubst:⧺:rrefl/shift" 100
  [| do n ← randSml @ ℕ64
        𝓈 ← randSml @ (SSubst ULCDExpR)
        e ← randSml @ ULCDExpR
        return $ n :* 𝓈 :* e
  |]
  [| \ (n :* 𝓈 :* e) → ssubst (𝓈 ⧺ 𝓈shift n null) e ≡ ssubst 𝓈 e 
  |]

𝔣 "zzz:ssubst:⧺:trans" 100 
  [| do 𝓈₁ ← randSml @ (SSubst ULCDExpR)
        𝓈₂ ← randSml @ (SSubst ULCDExpR)
        𝓈₃ ← randSml @ (SSubst ULCDExpR)
        e ← randSml @ ULCDExpR
        return $ 𝓈₁ :* 𝓈₂ :* 𝓈₃ :* e
  |]
  [| \ (𝓈₁ :* 𝓈₂ :* 𝓈₃ :* e) → 
       ssubst ((𝓈₁ ⧺ 𝓈₂) ⧺ 𝓈₃) e ≡ ssubst (𝓈₁ ⧺ (𝓈₂ ⧺ 𝓈₃)) e 
  |]

𝔣 "zzz:ssubst:shift/⧺:shift:dist" 100 
  [| do n ← randSml @ ℕ64
        𝓈₁ ← randSml @ (SSubst ULCDExpR)
        𝓈₂ ← randSml @ (SSubst ULCDExpR)
        e ← randSml @ ULCDExpR
        return $ n :* 𝓈₁ :* 𝓈₂ :* e
  |]
  [| \ (n :* 𝓈₁ :* 𝓈₂ :* e) → 
       ssubst (𝓈shift n (𝓈₁ ⧺ 𝓈₂)) e ≡ ssubst (𝓈shift n 𝓈₁ ⧺ 𝓈shift n 𝓈₂) e 
  |]

𝔣 "zzz:usubst:⧺:hom" 100 
  [| do 𝓈₁ ← randSml @ (USubst ULCDExpR)
        𝓈₂ ← randSml @ (USubst ULCDExpR)
        e ← randSml @ ULCDExpR
        return $ 𝓈₁ :* 𝓈₂ :* e
  |]
  [| \ (𝓈₁ :* 𝓈₂ :* e) → 
       usubst (𝓈₁ ⧺ 𝓈₂) e ≡ usubst 𝓈₁ (usubst 𝓈₂ e)
  |]

𝔣 "zzz:usubst:⧺:lrefl" 100 
  [| do 𝓈 ← randSml @ (USubst ULCDExpR)
        e ← randSml @ ULCDExpR
        return $ 𝓈 :* e
  |]
  [| \ (𝓈 :* e) → 
       usubst (null ⧺ 𝓈) e ≡ usubst 𝓈 e
  |]

𝔣 "zzz:usubst:⧺:rrefl" 100 
  [| do 𝓈 ← randSml @ (USubst ULCDExpR)
        e ← randSml @ ULCDExpR
        return $ 𝓈 :* e
  |]
  [| \ (𝓈 :* e) → 
       usubst (𝓈 ⧺ null) e ≡ usubst 𝓈 e
  |]

𝔣 "zzz:usubst:⧺:trans" 100 
  [| do 𝓈₁ ← randSml @ (USubst ULCDExpR)
        𝓈₂ ← randSml @ (USubst ULCDExpR)
        𝓈₃ ← randSml @ (USubst ULCDExpR)
        e ← randSml @ ULCDExpR
        return $ 𝓈₁ :* 𝓈₂ :* 𝓈₃ :* e
  |]
  [| \ (𝓈₁ :* 𝓈₂ :* 𝓈₃ :* e) → 
       usubst ((𝓈₁ ⧺ 𝓈₂) ⧺ 𝓈₃) e ≡ usubst (𝓈₁ ⧺ (𝓈₂ ⧺ 𝓈₃)) e 
  |]

buildTests
