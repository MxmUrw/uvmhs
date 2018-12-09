module UVMHS.Core.Effects where

import UVMHS.Init
import UVMHS.Core.Classes
import UVMHS.Core.Data

import UVMHS.Core.Lens

infixl 4 ⊞,⎅

class MonadIO (m ∷ ★ → ★) where io ∷ IO a → m a

class LiftIO t where
  liftIO ∷ ∀ m. (Monad m) ⇒ (∀ a. IO a → m a) → (∀ a. IO a → t m a)

class MonadReader r m | m → r where
  ask ∷ m r
  local ∷ ∀ a. r → m a → m a

class LiftReader t where
  liftAsk ∷ ∀ m r. (Monad m) ⇒ m r → t m r
  liftLocal ∷ ∀ m r. (Monad m) ⇒ (∀ a. r → m a → m a) → (∀ a. r → t m a → t m a)

class MonadWriter o m | m → o where
  tell ∷ o → m ()
  listen ∷ ∀ a. m a → m (o ∧ a)

class LiftWriter t where
  liftTell ∷ ∀ m o. (Monad m) ⇒ (o → m ()) → (o → t m ())
  liftListen ∷ ∀ m o. (Monad m) ⇒ (∀ a. m a → m (o ∧ a)) → (∀ a. t m a → t m (o ∧ a))

class MonadState s m | m → s where
  get ∷ m s
  put ∷ s → m ()

class LiftState t where
  liftGet ∷ ∀ m s. (Monad m) ⇒ m s → t m s
  liftPut ∷ ∀ m s. (Monad m) ⇒ (s → m ()) → (s → t m ())

class MonadFail m where
  abort ∷ ∀ a. m a
  (⎅) ∷ ∀ a. m a → m a → m a

class LiftFail t where
  liftAbort ∷ ∀ m. (Monad m) ⇒ (∀ a. m a) → (∀ a. t m a)
  liftTry ∷ ∀ m. (Monad m) ⇒ (∀ a. m a → m a → m a) → (∀ a. t m a → t m a → t m a)

class MonadError e m | m → e where
  throw ∷ ∀ a. e → m a
  catch ∷ ∀ a. m a → (e → m a) → m a

class LiftError t where
  liftThrow ∷ ∀ m e. (Monad m) ⇒ (∀ a. e → m a) → (∀ a. e → t m a)
  liftCatch ∷ ∀ m e. (Monad m) ⇒ (∀ a. m a → (e → m a) → m a) → (∀ a. t m a → (e → t m a) → t m a)

class MonadNondet m where
  mzero ∷ ∀ a. m a
  (⊞) ∷ ∀ a. m a → m a → m a

class LiftNondet t where
  liftMzero ∷ ∀ m. (Monad m) ⇒ (∀ a. m a) → (∀ a. t m a)
  liftMplus ∷ ∀ m. (Monad m) ⇒ (∀ a. m a → m a → m a) → (∀ a. t m a → t m a → t m a)

class MonadTop m where
  mtop ∷ ∀ a. m a

class LiftTop t where
  liftMtop ∷ ∀ m. (Monad m) ⇒ (∀ a. m a) → (∀ a. t m a)

class MonadCont r m | m → r where
  callCC ∷ ∀ a. ((a → m r) → m r) → m a 
  withC ∷ ∀ a. (a → m r) → m a → m r 

class LiftCont t where
  liftCallCC ∷ ∀ m r. (Monad m) ⇒ (∀ a. ((a → m r) → m r) → m a) → (∀ a. ((a → t m r) → t m r) → t m a)
  liftWithC ∷ ∀ m r. (Monad m) ⇒ (∀ a. (a → m r) → m a → m r) → (∀ a. (a → t m r) → t m a → t m r)

------------------------
-- STANDARD INSTANCES --
------------------------

instance MonadReader r ((→) r) where
  ask ∷ r → r
  ask = id

  local ∷ ∀ a. r → (r → a) → (r → a)
  local r f = const $ f r

instance (Null o) ⇒ MonadWriter o ((∧) o) where
  tell ∷ o → (o ∧ ())
  tell o = (o :꘍ ())

  listen ∷ ∀ a. o ∧ a → o ∧ (o ∧ a)
  listen ox = null :꘍ ox

instance MonadFail 𝑂 where
  abort ∷ ∀ a. 𝑂 a
  abort = None

  (⎅) ∷ ∀ a. 𝑂 a → 𝑂 a → 𝑂 a
  None ⎅ xM = xM
  Some x ⎅ _ = Some x

instance MonadError e ((∨) e) where
  throw ∷ ∀ a. e → e ∨ a
  throw = Inl

  catch ∷ ∀ a. e ∨ a → (e → e ∨ a) → e ∨ a
  catch (Inl e) k = k e
  catch (Inr x) _ = Inr x

instance MonadNondet 𝐼 where
  mzero ∷ ∀ a. 𝐼 a
  mzero = null

  (⊞) ∷ ∀ a. 𝐼 a → 𝐼 a → 𝐼 a
  (⊞) = (⧺)

instance MonadNondet 𝐿 where
  mzero ∷ ∀ a. 𝐿 a
  mzero = null

  (⊞) ∷ ∀ a. 𝐿 a → 𝐿 a → 𝐿 a
  (⊞) = (⧺)

instance MonadNondet 𝑄 where
  mzero ∷ ∀ a. 𝑄 a
  mzero = null

  (⊞) ∷ ∀ a. 𝑄 a → 𝑄 a → 𝑄 a
  (⊞) = (⧺)

----------------
-- OPERATIONS --
----------------

-- Reader

askL ∷ (Monad m,MonadReader r m) ⇒ r ⟢ a → m a 
askL l = access l ^$ ask

mapEnv ∷ (Monad m,MonadReader r m) ⇒ (r → r) → m a → m a 
mapEnv f aM = do
  r ← ask
  local (f r) aM

localL ∷ (Monad m,MonadReader r₁ m) ⇒ (r₁ ⟢ r₂) → r₂ → m a → m a
localL 𝓁 r = mapEnv $ update 𝓁 r

mapEnvL ∷ (Monad m,MonadReader r₁ m) ⇒ (r₁ ⟢ r₂) → (r₂ → r₂) → m a → m a
mapEnvL 𝓁 f = mapEnv $ alter 𝓁 f

-- Writer

tellL ∷ (Monoid o₁,Monad m,MonadWriter o₁ m) ⇒ o₁ ⟢ o₂ → o₂ → m ()
tellL l o = tell $ update l o null

listenL ∷ (Monad m,MonadWriter o₁ m,Monoid o₂) ⇒ o₁ ⟢ o₂ → m a → m (o₂ ∧ a)
listenL l aM = do
  (o₁ :꘍ a) ← listen aM
  tell $ update l null o₁
  return (access l o₁ :꘍ a)

mapOut ∷ (Monad m,MonadWriter o m) ⇒ (o → o) → m a → m a
mapOut f aM = do
  (o :꘍ a) ← listen aM
  tell $ f o
  return a

retOut ∷ ∀ o m a. (Monad m,MonadWriter o m) ⇒ m a → m o
retOut xM = do
  (o :꘍ _) ← listen xM
  return o

-- # State

getL ∷ (Monad m,MonadState s m) ⇒ s ⟢ a → m a 
getL l = map (access l) get

putL ∷ (Monad m,MonadState s m) ⇒ s ⟢ a → a → m () 
putL 𝓁 = modify ∘ update 𝓁

modify ∷ (Monad m,MonadState s m) ⇒ (s → s) → m () 
modify f = do
  s ← get
  put $ f s

modifyL ∷ (Monad m,MonadState s m) ⇒ s ⟢ a → (a → a) → m () 
modifyL 𝓁 = modify ∘ alter 𝓁

getput ∷ (Monad m,MonadState s m) ⇒ s → m s
getput s = do
  s' ← get
  put s
  return s'

getputL ∷ (Monad m,MonadState s₁ m) ⇒ s₁ ⟢ s₂ → s₂ → m s₂
getputL 𝓁 x = do
  x' ← getL 𝓁
  putL 𝓁 x
  return x'

next ∷ (Monad m,MonadState s m,Multiplicative s) ⇒ m s
next = do
  i ← get
  put $ succ i
  return i

nextL ∷ (Monad m,MonadState s m,Multiplicative a) ⇒ s ⟢ a → m a
nextL l = do
  i ← getL l
  putL l $ succ i
  return i

bump ∷ (Monad m,MonadState s m,Multiplicative s) ⇒ m ()
bump = modify succ

bumpL ∷ (Monad m,MonadState s m,Multiplicative a) ⇒ s ⟢ a → m ()
bumpL l = modifyL l succ

localize ∷ (Monad m,MonadState s m) ⇒ s → m a → m (s ∧ a)
localize s xM = do
  s' ← getput s
  x ← xM
  s'' ← getput s'
  return (s'' :꘍ x)

localizeL ∷ (Monad m,MonadState s₁ m) ⇒ s₁ ⟢ s₂ → s₂ → m a → m (s₂ ∧ a)
localizeL 𝓁 s₂ aM = do
  s₂' ← getputL 𝓁 s₂
  x ← aM
  s₂'' ← getputL 𝓁 s₂'
  return (s₂'' :꘍ x)

localState ∷ (Monad m,MonadState s m) ⇒ s → m a → m a
localState s = map snd ∘ localize s

localStateL ∷ (Monad m,MonadState s₁ m) ⇒ s₁ ⟢ s₂ → s₂ → m a → m a
localStateL 𝓁 s = map snd ∘ localizeL 𝓁 s

retState ∷ ∀ s m a. (Monad m,MonadState s m) ⇒ m a → m s
retState xM = do
  _ ← xM
  get

-- Fail

abort𝑂 ∷ ∀ m a. (Monad m,MonadFail m) ⇒ 𝑂 a → m a
abort𝑂 = elim𝑂 abort return

tries ∷ (Monad m,MonadFail m,ToIter (m a) t) ⇒ t → m a
tries = foldr abort (⎅)

-- Error

throw𝑂 ∷ (Monad m,MonadError e m) ⇒ e → 𝑂 a → m a 
throw𝑂 e = elim𝑂 (throw e) return

-- # Nondet

mconcat ∷ (MonadNondet m,ToIter (m a) t) ⇒ t → m a
mconcat = foldr mzero (⊞)

from ∷ (Monad m,MonadNondet m,ToIter a t) ⇒ t → m a
from = mconcat ∘ map return ∘ iter

oneOrMoreSplit ∷ (Monad m,MonadNondet m) ⇒ m a → m (a ∧ 𝐿 a)
oneOrMoreSplit aM = do
  x ← aM
  xs ← many aM
  return (x :꘍ xs)

oneOrMore ∷ (Monad m,MonadNondet m) ⇒ m a → m (𝐿 a)
oneOrMore xM = do
  (x :꘍ xs) ← oneOrMoreSplit xM
  return (x :& xs)

many ∷ (Monad m,MonadNondet m) ⇒ m a → m (𝐿 a)
many aM = mconcat
  [ oneOrMore aM
  , return null
  ]

twoOrMoreSplit ∷ (Monad m,MonadNondet m) ⇒ m a → m (a ∧ a ∧ 𝐿 a)
twoOrMoreSplit aM = do
  x₁ ← aM
  (x₂ :꘍ xs) ← oneOrMoreSplit aM
  return (x₁ :꘍ x₂ :꘍ xs)

manySepBy ∷ (Monad m,MonadNondet m) ⇒ m () → m a → m (𝐿 a)
manySepBy uM xM = mconcat
  [ do
      x ← xM
      xs ← manyPrefBy uM xM
      return $ x :& xs
  , return null
  ]

manyPrefBy ∷ (Monad m,MonadNondet m) ⇒ m () → m a → m (𝐿 a)
manyPrefBy uM xM = mconcat
  [ do
      uM
      x ← xM
      xs ← manyPrefBy uM xM
      return $ x :& xs
  , return null
  ]

mzero𝑂 ∷ (Monad m,MonadNondet m) ⇒ 𝑂 a → m a
mzero𝑂 = elim𝑂 mzero return

return𝑃 ∷ ∀ m a. (Monad m,MonadNondet m) ⇒ 𝑃 a → m a
return𝑃 = fold mzero (\ x xM → xM ⊞ return x)

-- Cont

reset ∷ (Monad m,MonadCont r m) ⇒ m r → m r 
reset aM = callCC $ \ k → k *$ withC return aM

modifyC ∷ (Monad m,MonadCont r m) ⇒ (r → m r) → m a → m a 
modifyC f aM = callCC $ \ k → withC (f *∘ k) aM

withCOn ∷ (Monad m,MonadCont r m) ⇒ m a → (a → m r) → m r
withCOn = flip withC

--------------
-- DERIVING --
--------------

deriveAsk ∷ ∀ m₁ m₂ r. (m₁ ⇄⁻ m₂,MonadReader r m₂) ⇒ m₁ r
deriveAsk = isofr2 ask

deriveLocal ∷ ∀ m₁ m₂ r a. (m₁ ⇄⁻ m₂,MonadReader r m₂) ⇒ r → m₁ a → m₁ a
deriveLocal r = isofr2 ∘ local r ∘ isoto2

deriveTell ∷ ∀ m₁ m₂ o. (m₁ ⇄⁻ m₂,MonadWriter o m₂) ⇒ o → m₁ ()
deriveTell = isofr2 ∘ tell

deriveListen ∷ ∀ m₁ m₂ o a. (m₁ ⇄⁻ m₂,MonadWriter o m₂) ⇒ m₁ a → m₁ (o ∧ a)
deriveListen = isofr2 ∘ listen ∘ isoto2

deriveGet ∷ ∀ m₁ m₂ s. (m₁ ⇄⁻ m₂,MonadState s m₂) ⇒ m₁ s
deriveGet = isofr2 get

derivePut ∷ ∀ m₁ m₂ s. (m₁ ⇄⁻ m₂,MonadState s m₂) ⇒ s → m₁ ()
derivePut = isofr2 ∘ put

deriveAbort ∷ ∀ m₁ m₂ a. (m₁ ⇄⁻ m₂,MonadFail m₂) ⇒ m₁ a
deriveAbort = isofr2 abort

deriveTry ∷ ∀ m₁ m₂ a. (m₁ ⇄⁻ m₂,MonadFail m₂) ⇒ m₁ a → m₁ a → m₁ a
deriveTry xM₁ xM₂ = isofr2 $ isoto2 xM₁ ⎅ isoto2 xM₂

deriveThrow ∷ ∀ m₁ m₂ e a. (m₁ ⇄⁻ m₂,MonadError e m₂) ⇒ e → m₁ a
deriveThrow e = isofr2 $ throw e

deriveCatch ∷ ∀ m₁ m₂ e a. (m₁ ⇄⁻ m₂,MonadError e m₂) ⇒ m₁ a → (e → m₁ a) → m₁ a
deriveCatch xM k = isofr2 $ catch (isoto2 xM) (isoto2 ∘ k)

deriveMzero ∷ ∀ m₁ m₂ a. (m₁ ⇄⁻ m₂,MonadNondet m₂) ⇒ m₁ a
deriveMzero = isofr2 mzero

deriveMplus ∷ ∀ m₁ m₂ a. (m₁ ⇄⁻ m₂,MonadNondet m₂) ⇒ m₁ a → m₁ a → m₁ a
deriveMplus xM₁ xM₂ = isofr2 $ isoto2 xM₁ ⊞ isoto2 xM₂

deriveMtop ∷ ∀ m₁ m₂ a. (m₁ ⇄⁻ m₂,MonadTop m₂) ⇒ m₁ a
deriveMtop = isofr2 mtop

deriveCallCC ∷ ∀ m₁ m₂ r a. (m₁ ⇄⁻ m₂,MonadCont r m₂) ⇒ ((a → m₁ r) → m₁ r) → m₁ a
deriveCallCC ff = isofr2 $ callCC $ \ k → isoto2 $ ff (isofr2 ∘ k)

deriveWithC ∷ ∀ m₁ m₂ r a. (m₁ ⇄⁻ m₂,MonadCont r m₂) ⇒ (a → m₁ r) → m₁ a → m₁ r
deriveWithC k xM = isofr2 $ withC (isoto2 ∘ k) (isoto2 xM)

