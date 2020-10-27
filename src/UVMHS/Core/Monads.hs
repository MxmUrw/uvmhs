module UVMHS.Core.Monads where

import UVMHS.Core.Init
import UVMHS.Core.Classes
import UVMHS.Core.Data

import UVMHS.Core.Effects
import UVMHS.Core.Transformers

import qualified Prelude as HS

instance MonadIO IO where 
  {-# INLINE io #-}
  io = id

instance Functor IO where 
  {-# INLINE map #-}
  map = mmap
instance Return IO where 
  {-# INLINE return #-}
  return = HS.return
instance Bind IO where 
  {-# INLINE (≫=) #-}
  (≫=) = (HS.>>=)
instance Monad IO

newtype ID a = ID { unID ∷ a }
  deriving 
  (Null,Append,Monoid
  ,Bot,Join,JoinLattice
  ,Top,Meet,MeetLattice
  ,Lattice,Dual,Difference)

instance Functor ID where 
  {-# INLINE map #-}
  map = mmap
instance Return ID where
  {-# INLINE return #-}
  return ∷ ∀ a. a → ID a
  return = ID
instance Bind ID where
  {-# INLINE (≫=) #-}
  (≫=) ∷ ∀ a b. ID a → (a → ID b) → ID b
  x ≫= f = f $ unID x
instance Monad ID

instance Extract ID where
  {-# INLINE extract #-}
  extract ∷ ∀ a. ID a → a
  extract = unID
instance Cobind ID where
  {-# INLINE (=≫) #-}
  (=≫) ∷ ∀ a b. ID a → (ID a → b) → ID b
  xM =≫ f = ID $ f xM
instance Comonad ID

------------
-- READER --
------------

newtype ReaderT r m a = ReaderT { unReaderT ∷ r → m a }

{-# INLINE runReaderT #-}
runReaderT ∷ ∀ r m a. r → ReaderT r m a → m a
runReaderT r xM = unReaderT xM r

instance (Functor m) ⇒ Functor (ReaderT r m) where 
  {-# INLINE map #-}
  map ∷ ∀ a b. (a → b) → ReaderT r m a → ReaderT r m b
  map f = ReaderT ∘ map (map f) ∘ unReaderT
instance (Return m) ⇒ Return (ReaderT r m) where
  {-# INLINE return #-}
  return ∷ ∀ a. a → ReaderT r m a
  return x = ReaderT $ \ _ → return x
instance (Bind m) ⇒ Bind (ReaderT r m) where
  {-# INLINE (≫=) #-}
  (≫=) ∷ ∀ a b. ReaderT r m a → (a → ReaderT r m b) → ReaderT r m b
  xM ≫= k = ReaderT $ \ r → do
    x ← unReaderT xM r
    unReaderT (k x) r
instance (Monad m) ⇒ Monad (ReaderT r m)

instance Functor2 (ReaderT r) where
  {-# INLINE map2 #-}
  map2 ∷ ∀ m₁ m₂. (∀ a. m₁ a → m₂ a) → (∀ a. ReaderT r m₁ a → ReaderT r m₂ a)
  map2 f = ReaderT ∘ map f ∘ unReaderT

instance (Monad m) ⇒ MonadReader r (ReaderT r m) where
  {-# INLINE ask #-}
  ask ∷ ReaderT r m r
  ask = ReaderT $ \ r → return r

  {-# INLINE local #-}
  local ∷ ∀ a. r → ReaderT r m a → ReaderT r m a
  local r xM = ReaderT $ \ _ → unReaderT xM r

instance (∀ a'. Null a' ⇒ Null (m a'),Null a) ⇒ Null (ReaderT r m a) where
  {-# INLINE null #-}
  null ∷ ReaderT r m a
  null = ReaderT $ \ _ → null
instance (∀ a'. Append a' ⇒ Append (m a'),Append a) ⇒ Append (ReaderT r m a) where
  {-# INLINE (⧺) #-}
  (⧺) ∷ ReaderT r m a → ReaderT r m a → ReaderT r m a
  (⧺) xM₁ xM₂ = ReaderT $ \ r → unReaderT xM₁ r ⧺ unReaderT xM₂ r

instance Transformer (ReaderT r) where
  {-# INLINE lift #-}
  lift ∷ ∀ m a. (Monad m) ⇒ m a → ReaderT r m a
  lift xM = ReaderT $ \ _ → xM

------------
-- WRITER --
------------

newtype WriterT o m a = WriterT { unWriterT ∷ m (o ∧ a) }

{-# INLINE evalWriterT #-}
evalWriterT ∷ ∀ o m a. (Functor m) ⇒ WriterT o m a → m a
evalWriterT = map snd ∘ unWriterT

instance (Functor m) ⇒ Functor (WriterT o m) where 
  {-# INLINE map #-}
  map ∷ ∀ a b. (a → b) → WriterT o m a → WriterT o m b
  map f = WriterT ∘ map (map f) ∘ unWriterT

instance (Return m,Null o) ⇒ Return (WriterT o m) where
  {-# INLINE return #-}
  return ∷ ∀ a. a → WriterT o m a
  return x = WriterT $ return (null :* x)
instance (Monad m,Append o) ⇒ Bind (WriterT o m) where
  {-# INLINE (≫=) #-}
  (≫=) ∷ ∀ a b. WriterT o m a → (a → WriterT o m b) → WriterT o m b
  xM ≫= k = WriterT $ do
    (o₁ :* x) ← unWriterT xM
    (o₂ :* y) ← unWriterT $ k x
    return ((o₁ ⧺ o₂) :* y)
instance (Monad m,Monoid o) ⇒ Monad (WriterT o m)

instance (Monoid o) ⇒ Functor2 (WriterT o) where
  {-# INLINE map2 #-}
  map2 ∷ ∀ m₁ m₂. (∀ a. m₁ a → m₂ a) → (∀ a. WriterT o m₁ a → WriterT o m₂ a)
  map2 f = WriterT ∘ f ∘ unWriterT

instance (Monad m,Null o) ⇒ MonadWriter o (WriterT o m) where
  {-# INLINE tell #-}
  tell ∷ o → WriterT o m ()
  tell o = WriterT $ return (o :* ())

  {-# INLINE hijack #-}
  hijack ∷ ∀ a. WriterT o m a → WriterT o m (o ∧ a)
  hijack xM = WriterT $ do
    oa ← unWriterT xM
    return $ null :* oa

instance (∀ a'. Null a' ⇒ Null (m a'),Null o,Null a) ⇒ Null (WriterT o m a) where
  {-# INLINE null #-}
  null ∷ WriterT o m a
  null = WriterT null
instance (∀ a'. Append a' ⇒ Append (m a'),Append o,Append a) ⇒ Append (WriterT o m a) where
  {-# INLINE (⧺) #-}
  (⧺) ∷ WriterT o m a → WriterT o m a → WriterT o m a
  xM₁ ⧺ xM₂ = WriterT $ unWriterT xM₁ ⧺ unWriterT xM₂
instance 
  (∀ a'. Null a' ⇒ Null (m a')
  ,∀ a'. Append a' ⇒ Append (m a')
  ,∀ a'. Monoid a' ⇒ Monoid (m a')
  ,Monoid o,Monoid a) 
  ⇒ Monoid (WriterT o m a)

instance (Null o) ⇒ Transformer (WriterT o) where
  {-# INLINE lift #-}
  lift ∷ ∀ m a. (Monad m) ⇒ m a → WriterT o m a
  lift xM = WriterT $ (null :*) ^$ xM

-----------
-- STATE --
-----------

newtype StateT s m a = StateT { unStateT ∷ s → m (s ∧ a) }

{-# INLINE runStateT #-}
runStateT ∷ ∀ s m a. s → StateT s m a → m (s ∧ a)
runStateT s xM = unStateT xM s

{-# INLINE evalStateT #-}
evalStateT ∷ ∀ s m a. (Functor m) ⇒ s → StateT s m a → m a
evalStateT s = map snd ∘ runStateT s

instance (Functor m) ⇒ Functor (StateT s m) where 
  {-# INLINE map #-}
  map ∷ ∀ a b. (a → b) → StateT s m a → StateT s m b
  map f = StateT ∘ map (map (map f)) ∘ unStateT

instance (Return m) ⇒ Return (StateT s m) where
  {-# INLINE return #-}
  return ∷ ∀ a. a → StateT s m a
  return x = StateT $ \ s → return (s :* x)
instance (Bind m) ⇒ Bind (StateT s m) where
  {-# INLINE (≫=) #-}
  (≫=) ∷ ∀ a b. StateT s m a → (a → StateT s m b) → StateT s m b
  xM ≫= k = StateT $ \ s → do
    (s' :* x) ← unStateT xM s
    unStateT (k x) s'
instance (Monad m) ⇒ Monad (StateT s m)

instance Functor2 (StateT s) where
  {-# INLINE map2 #-}
  map2 ∷ ∀ m₁ m₂. (∀ a. m₁ a → m₂ a) → (∀ a. StateT s m₁ a → StateT s m₂ a)
  map2 f = StateT ∘ map f ∘ unStateT

instance (Return m) ⇒ MonadState s (StateT s m) where
  {-# INLINE get #-}
  get ∷ StateT s m s
  get = StateT $ \ s → return (s :* s)
  
  {-# INLINE put #-}
  put ∷ s → StateT s m ()
  put s = StateT $ \ _ → return (s :* ())

instance (∀ a'. Null a' ⇒ Null (m a'),Null s,Null a) ⇒ Null (StateT s m a) where
  {-# INLINE null #-}
  null ∷ StateT s m a
  null = StateT $ \ _ → null
instance (∀ a'. Append a' ⇒ Append (m a'),Append s,Append a) ⇒ Append (StateT s m a) where
  {-# INLINE (⧺) #-}
  (⧺) ∷ StateT s m a → StateT s m a → StateT s m a
  xM₁ ⧺ xM₂ = StateT $ \ s → unStateT xM₁ s ⧺ unStateT xM₂ s
instance 
  (∀ a'. Null a' ⇒ Null (m a')
  ,∀ a'. Append a' ⇒ Append (m a')
  ,∀ a'. Monoid a' ⇒ Monoid (m a')
  ,Monoid s,Monoid a) 
  ⇒ Monoid (StateT s m a)

type State s = StateT s ID

{-# INLINE runState #-}
runState ∷ s → State s a → (s ∧ a)
runState s = unID ∘ runStateT s

{-# INLINE evalState #-}
evalState ∷ s → State s a → a
evalState s = unID ∘ evalStateT s

instance Transformer (StateT s) where
  {-# INLINE lift #-}
  lift ∷ ∀ m a. (Monad m) ⇒ m a → StateT s m a
  lift xM = StateT $ \ s → (s :*) ^$ xM

----------
-- FAIL --
----------

newtype FailT m a = FailT { unFailT ∷ m (𝑂 a) }

instance (Functor m) ⇒ Functor (FailT m) where 
  {-# INLINE map #-}
  map ∷ ∀ a b. (a → b) → FailT m a → FailT m b
  map f = FailT ∘ map (map f) ∘ unFailT

instance (Return m) ⇒ Return (FailT m) where
  {-# INLINE return #-}
  return ∷ ∀ a. a → FailT m a
  return x = FailT $ return $ Some x
instance (Monad m) ⇒ Bind (FailT m) where
  {-# INLINE (≫=) #-}
  (≫=) ∷ ∀ a b. FailT m a → (a → FailT m b) → FailT m b
  xM ≫= k = FailT $ do
    xO ← unFailT xM
    case xO of
      None → return None
      Some x → unFailT $ k x
instance (Monad m) ⇒ Monad (FailT m)

instance Functor2 FailT where
  {-# INLINE map2 #-}
  map2 ∷ ∀ m₁ m₂. (∀ a. m₁ a → m₂ a) → (∀ a. FailT m₁ a → FailT m₂ a) 
  map2 f = FailT ∘ f ∘ unFailT

instance (Monad m) ⇒ MonadFail (FailT m) where
  {-# INLINE abort #-}
  abort ∷ ∀ a. FailT m a
  abort = FailT $ return None

  {-# INLINE (⎅) #-}
  (⎅) ∷ ∀ a. FailT m a → FailT m a → FailT m a
  xM₁ ⎅ xM₂ = FailT $ do
    xO₁ ← unFailT xM₁
    case xO₁ of
      None → unFailT xM₂
      Some x → return $ Some x

instance (∀ a'. Null a' ⇒ Null (m a'),Null a) ⇒ Null (FailT m a) where
  {-# INLINE null #-}
  null ∷ FailT m a
  null = FailT null
instance (∀ a'. Append a' ⇒ Append (m a'),Append a) ⇒ Append (FailT m a) where
  {-# INLINE (⧺) #-}
  (⧺) ∷ FailT m a → FailT m a → FailT m a
  xM₁ ⧺ xM₂ = FailT $ unFailT xM₁ ⧺ unFailT xM₂
instance 
  (∀ a'. Null a' ⇒ Null (m a')
  ,∀ a'. Append a' ⇒ Append (m a')
  ,∀ a'. Monoid a' ⇒ Monoid (m a')
  ,Monoid a) 
  ⇒ Monoid (FailT m a)

instance Transformer FailT where
  {-# INLINE lift #-}
  lift ∷ ∀ m a. (Monad m) ⇒ m a → FailT m a
  lift xM = FailT $ Some ^$ xM

-----------
-- ERROR --
-----------

newtype ErrorT e m a = ErrorT { unErrorT ∷ m (e ∨ a) }

instance (Functor m) ⇒ Functor (ErrorT e m) where
  {-# INLINE map #-}
  map ∷ ∀ a b. (a → b) → ErrorT e m a → ErrorT e m b
  map f = ErrorT ∘ map (map f) ∘ unErrorT

instance (Return m) ⇒ Return (ErrorT e m) where
  {-# INLINE return #-}
  return ∷ ∀ a. a → ErrorT e m a
  return x = ErrorT $ return $ Inr x
instance (Monad m) ⇒ Bind (ErrorT e m) where
  {-# INLINE (≫=) #-}
  (≫=) ∷ ∀ a b. ErrorT e m a → (a → ErrorT e m b) → ErrorT e m b
  xM ≫= k = ErrorT $ do
    ex ← unErrorT xM
    case ex of
      Inl e → return $ Inl e
      Inr x → unErrorT $ k x
instance (Monad m) ⇒ Monad (ErrorT e m)

instance Functor2 (ErrorT e) where
  {-# INLINE map2 #-}
  map2 ∷ ∀ m₁ m₂. (∀ a. m₁ a → m₂ a) → (∀ a. ErrorT e m₁ a → ErrorT e m₂ a)
  map2 f = ErrorT ∘ f ∘ unErrorT

instance (Monad m) ⇒ MonadError e (ErrorT e m) where
  {-# INLINE throw #-}
  throw ∷ ∀ a. e → ErrorT e m a
  throw e = ErrorT $ return $ Inl e

  {-# INLINE catch #-}
  catch ∷ ∀ a. ErrorT e m a → (e → ErrorT e m a) → ErrorT e m a
  catch xM k = ErrorT $ do
    ex ← unErrorT xM
    case ex of
      Inl e → unErrorT $ k e
      Inr x → return $ Inr x

instance (∀ a'. Null a' ⇒ Null (m a'),Null a) ⇒ Null (ErrorT e m a) where
  {-# INLINE null #-}
  null ∷ ErrorT e m a
  null = ErrorT null
instance (∀ a'. Append a' ⇒ Append (m a'),Append e,Append a) ⇒ Append (ErrorT e m a) where
  {-# INLINE (⧺) #-}
  (⧺) ∷ ErrorT e m a → ErrorT e m a → ErrorT e m a
  xM₁ ⧺ xM₂ = ErrorT $ unErrorT xM₁ ⧺ unErrorT xM₂
instance 
  (∀ a'. Null a' ⇒ Null (m a')
  ,∀ a'. Append a' ⇒ Append (m a')
  ,∀ a'. Monoid a' ⇒ Monoid (m a')
  ,Append e,Monoid a) 
  ⇒ Monoid (ErrorT e m a)

instance Transformer (ErrorT e) where
  {-# INLINE lift #-}
  lift ∷ ∀ m a. (Monad m) ⇒ m a → ErrorT e m a
  lift xM = ErrorT $ Inr ^$ xM

------------
-- NONDET --
------------

newtype NondetT m a = NondetT { unNondetT ∷ m (𝑄 a) }

instance (Functor m) ⇒ Functor (NondetT m) where 
  map ∷ ∀ a b. (a → b) → NondetT m a → NondetT m b
  map f xM = NondetT $ map (map f) $ unNondetT xM

instance (Return m) ⇒ Return (NondetT m) where
  return ∷ ∀ a. a → NondetT m a
  return x = NondetT $ return $ single x
instance (Bind m,∀ a'. Monoid a' ⇒ Monoid (m a')) ⇒ Bind (NondetT m) where
  (≫=) ∷ ∀ a b. NondetT m a → (a → NondetT m b) → NondetT m b
  xM ≫= k = NondetT $ do
    xs ← unNondetT xM
    unNondetT $ foldr mzero (⊞) $ map k $ iter xs
instance (Monad m,∀ a'. Monoid a' ⇒ Monoid (m a')) ⇒ Monad (NondetT m)

instance (∀ a'. Monoid a' ⇒ Monoid (m a')) ⇒ MonadNondet (NondetT m) where
  mzero ∷ ∀ a. NondetT m a
  mzero = NondetT $ null

  (⊞) ∷ ∀ a. NondetT m a → NondetT m a → NondetT m a
  xM₁ ⊞ xM₂ = NondetT $ unNondetT xM₁ ⧺ unNondetT xM₂

instance Transformer NondetT where
  {-# INLINE lift #-}
  lift ∷ ∀ m a. (Monad m) ⇒ m a → NondetT m a
  lift xM = NondetT $ single ^$ xM

----------
-- Cont --
----------

newtype ContT r m a = ContT { unContT ∷ (a → m r) → m r }

runContT ∷ (a → m r) → ContT r m a → m r
runContT = flip unContT

instance Functor (ContT r m) where
  map ∷ ∀ a b. (a → b) → ContT r m a → ContT r m b
  map f xM = ContT $ \ (k ∷ b → m r) → unContT xM $ \ x → k $ f x

instance Return (ContT r m) where
  return ∷ ∀ a. a → ContT r m a
  return x = ContT $ \ (k ∷ a → m r) → k x
instance Bind (ContT r m) where
  (≫=) ∷ ∀ a b. ContT r m a → (a → ContT r m b) → ContT r m b
  xM ≫= kk = ContT $ \ (k ∷ b → m r) → unContT xM $ \ (x ∷ a) → unContT (kk x) k
instance Monad (ContT r m)

instance Functor2Iso (ContT r) where
  map2iso ∷ ∀ m₁ m₂. Iso2 m₁ m₂ → ∀ a. ContT r m₁ a → ContT r m₂ a
  map2iso i xM = ContT $ \ (k ∷ a → m₂ r) → 
    ito2 i $ unContT xM $ \ (x ∷ a) → 
      ifr2 i $ k x

instance (Monad m) ⇒ MonadCont r (ContT r m) where
  callCC ∷ ∀ a. ((a → ContT r m r) → ContT r m r) → ContT r m a
  callCC kk = ContT $ \ (k ∷ a → m r) → 
    runContT return $ kk $ \ (x ∷ a) → 
      ContT $ \ (k' ∷ r → m r) → 
        k' *$ k x

  withC ∷ ∀ a. (a → ContT r m r) → ContT r m a → ContT r m r
  withC k₁ xM = ContT $ \ (k₂ ∷ r → m r) →
    k₂ *$ unContT xM $ \ (x ∷ a) → 
      runContT return $ k₁ x

instance (∀ a'. Null a' ⇒ Null (m a'),Null r) ⇒ Null (ContT r m a) where
  null ∷ ContT r m a
  null = ContT $ \ (_ ∷ a → m r) → null
instance (∀ a'. Append a' ⇒ Append (m a'),Append r) ⇒ Append (ContT r m a) where
  (⧺) ∷ ContT r m a → ContT r m a → ContT r m a
  xM₁ ⧺ xM₂ = ContT $ \ (k ∷ a → m r) → unContT xM₁ k ⧺ unContT xM₂ k
instance 
  (∀ a'. Null a' ⇒ Null (m a')
  ,∀ a'. Append a' ⇒ Append (m a')
  ,∀ a'. Monoid a' ⇒ Monoid (m a')
  ,Monoid r) 
  ⇒ Monoid (ContT r m a)

instance Transformer (ContT r) where
  {-# INLINE lift #-}
  lift ∷ ∀ m a. (Monad m) ⇒ m a → ContT r m a
  lift xM = ContT $ \ (κ ∷ a → m r) → κ *$ xM

-- ================= --
-- AUTOMATIC LIFTING --
-- ================= --

------------
-- READER --
------------

instance LiftIO (ReaderT r) where
  {-# INLINE liftIO #-}
  liftIO ∷ ∀ m. (Monad m) ⇒ (∀ a. IO a → m a) → (∀ a. IO a → ReaderT r m a)
  liftIO ioM xM = ReaderT $ \ _ → ioM xM

instance LiftReader (ReaderT r) where
  {-# INLINE liftAsk #-}
  liftAsk ∷ ∀ m r'. (Monad m) ⇒ m r' → ReaderT r m r'
  liftAsk askM = ReaderT $ \ _ → askM

  {-# INLINE liftLocal #-}
  liftLocal ∷ ∀ m r'. (Monad m) ⇒ (∀ a. r' → m a → m a) → (∀ a. r' → ReaderT r m a → ReaderT r m a)
  liftLocal localM r' xM = ReaderT $ \ r → localM r' $ unReaderT xM r

instance LiftWriter (ReaderT r) where
  {-# INLINE liftTell #-}
  liftTell ∷ ∀ m o. (Monad m) ⇒ (o → m ()) → (o → ReaderT r m ())
  liftTell tellM o = ReaderT $ \ _ → tellM o

  {-# INLINE liftHijack #-}
  liftHijack ∷ ∀ m o. (Monad m) ⇒ (∀ a. m a → m (o ∧ a)) → (∀ a. ReaderT r m a → ReaderT r m (o ∧ a))
  liftHijack hijackM xM = ReaderT $ \ r → hijackM $ unReaderT xM r

instance LiftState (ReaderT r) where
  {-# INLINE liftGet #-}
  liftGet ∷ ∀ m s. (Monad m) ⇒ m s → ReaderT r m s
  liftGet getM = ReaderT $ \ _ → getM

  {-# INLINE liftPut #-}
  liftPut ∷ ∀ m s. (Monad m) ⇒ (s → m ()) → (s → ReaderT r m ())
  liftPut putM s = ReaderT $ \ _ → putM s

instance LiftFail (ReaderT r) where
  {-# INLINE liftAbort #-}
  liftAbort ∷ ∀ m. (Monad m) ⇒ (∀ a. m a) → (∀ a. ReaderT r m a)
  liftAbort abortM = ReaderT $ \ _ → abortM

  {-# INLINE liftTry #-}
  liftTry ∷ ∀ m. (Monad m) ⇒ (∀ a. m a → m a → m a) → (∀ a. ReaderT r m a → ReaderT r m a → ReaderT r m a)
  liftTry tryM xM₁ xM₂ = ReaderT $ \ r → tryM (unReaderT xM₁ r) (unReaderT xM₂ r)

instance LiftError (ReaderT r) where
  {-# INLINE liftThrow #-}
  liftThrow ∷ ∀ m e. (Monad m) ⇒ (∀ a. e → m a) → (∀ a. e → ReaderT r m a)
  liftThrow throwM e = ReaderT $ \ _ → throwM e

  {-# INLINE liftCatch #-}
  liftCatch ∷ ∀ m e. (Monad m) ⇒ (∀ a. m a → (e → m a) → m a) → (∀ a. ReaderT r m a → (e → ReaderT r m a) → ReaderT r m a)
  liftCatch catchM xM k = ReaderT $ \ r → catchM (unReaderT xM r) (\ e → unReaderT (k e) r)

instance LiftNondet (ReaderT r) where
  {-# INLINE liftMzero #-}
  liftMzero ∷ ∀ m. (Monad m) ⇒ (∀ a. m a) → (∀ a. ReaderT r m a)
  liftMzero mzeroM = ReaderT $ \ _ → mzeroM

  {-# INLINE liftMplus #-}
  liftMplus ∷ ∀ m. (Monad m) ⇒ (∀ a. m a → m a → m a) → (∀ a. ReaderT r m a → ReaderT r m a → ReaderT r m a)
  liftMplus mplusM xM₁ xM₂ = ReaderT $ \ r → mplusM (unReaderT xM₁ r) (unReaderT xM₂ r)
    
instance LiftTop (ReaderT r) where
  {-# INLINE liftMtop #-}
  liftMtop ∷ ∀ m. (Monad m) ⇒ (∀ a. m a) → (∀ a. ReaderT r m a)
  liftMtop mtopM = ReaderT $ \ _ → mtopM

instance LiftCont (ReaderT r) where
  {-# INLINE liftCallCC #-}
  liftCallCC ∷ ∀ m r'. (Monad m) ⇒ (∀ a. ((a → m r') → m r') → m a) → (∀ a. ((a → ReaderT r m r') → ReaderT r m r') → ReaderT r m a)
  liftCallCC callCCM kk = ReaderT $ \ r → 
    callCCM $ \ (k ∷ a → m r') → 
      runReaderT r $ kk $ \ (x ∷ a) → 
        ReaderT $ \ _ → 
          k x
  {-# INLINE liftWithC #-}
  liftWithC ∷ ∀ m r'. (Monad m) ⇒ (∀ a. (a → m r') → m a → m r') → (∀ a. (a → ReaderT r m r') → ReaderT r m a → ReaderT r m r')
  liftWithC withCM k xM = ReaderT $ \ r →
    withCM (\ x → unReaderT (k x) r) $ unReaderT xM r

------------
-- WRITER --
------------

instance (Null o) ⇒ LiftIO (WriterT o) where
  {-# INLINE liftIO #-}
  liftIO ∷ ∀ m. (Monad m) ⇒ (∀ a. IO a → m a) → (∀ a. IO a → WriterT o m a)
  liftIO ioM xM = WriterT $ do
    x ← ioM xM
    return (null :* x)

instance (Null o) ⇒ LiftReader (WriterT o) where
  {-# INLINE liftAsk #-}
  liftAsk ∷ ∀ m r. (Monad m) ⇒ m r → WriterT o m r
  liftAsk askM = WriterT $ do
    r ← askM
    return (null :* r)

  {-# INLINE liftLocal #-}
  liftLocal ∷ ∀ m r. (Monad m) ⇒ (∀ a. r → m a → m a) → (∀ a. r → WriterT o m a → WriterT o m a)
  liftLocal localM r xM = WriterT $ localM r $ unWriterT xM
    
instance (Null o) ⇒ LiftWriter (WriterT o) where
  {-# INLINE liftTell #-}
  liftTell ∷ ∀ m o'. (Monad m) ⇒ (o' → m ()) → (o' → WriterT o m ())
  liftTell tellM o' = WriterT $ do
    tellM o'
    return (null :* ())

  {-# INLINE liftHijack #-}
  liftHijack ∷ ∀ m o'. (Monad m) ⇒ (∀ a. m a → m (o' ∧ a)) → (∀ a. WriterT o m a → WriterT o m (o' ∧ a))
  liftHijack hijackM xM = WriterT $ do
    (o' :* (o :* a)) ← hijackM $ unWriterT xM
    return (o :* (o' :* a))

instance (Null o) ⇒ LiftState (WriterT o) where
  {-# INLINE liftGet #-}
  liftGet ∷ ∀ m s. (Monad m) ⇒ m s → WriterT o m s
  liftGet getM = WriterT $ do
    s ← getM
    return (null :* s)

  {-# INLINE liftPut #-}
  liftPut ∷ ∀ m s. (Monad m) ⇒ (s → m ()) → (s → WriterT o m ())
  liftPut putM s = WriterT $ do
    putM s
    return (null :* ())

instance LiftFail (WriterT o) where
  {-# INLINE liftAbort #-}
  liftAbort ∷ ∀ m. (Monad m) ⇒ (∀ a. m a) → (∀ a. WriterT o m a)
  liftAbort abortM = WriterT abortM

  {-# INLINE liftTry #-}
  liftTry ∷ ∀ m. (Monad m) ⇒ (∀ a. m a → m a → m a) → (∀ a. WriterT o m a → WriterT o m a → WriterT o m a)
  liftTry tryM xM₁ xM₂ = WriterT $ tryM (unWriterT xM₁) (unWriterT xM₂)

instance LiftError (WriterT o) where
  {-# INLINE liftThrow #-}
  liftThrow ∷ ∀ m e. (Monad m) ⇒ (∀ a. e → m a) → (∀ a. e → WriterT o m a)
  liftThrow throwM e = WriterT $ throwM e

  {-# INLINE liftCatch #-}
  liftCatch ∷ ∀ m e. (Monad m) ⇒ (∀ a. m a → (e → m a) → m a) → (∀ a. WriterT o m a → (e → WriterT o m a) → WriterT o m a)
  liftCatch catchM xM k = WriterT $ catchM (unWriterT xM) $ \ e → unWriterT $ k e

instance LiftNondet (WriterT o) where
  {-# INLINE liftMzero #-}
  liftMzero ∷ ∀ m. (Monad m) ⇒ (∀ a. m a) → (∀ a. WriterT o m a)
  liftMzero mzeroM = WriterT mzeroM

  {-# INLINE liftMplus #-}
  liftMplus ∷ ∀ m. (Monad m) ⇒ (∀ a. m a → m a → m a) → (∀ a. WriterT o m a → WriterT o m a → WriterT o m a)
  liftMplus mplusM xM₁ xM₂ = WriterT $ mplusM (unWriterT xM₁) (unWriterT xM₂)

instance LiftTop (WriterT o) where
  {-# INLINE liftMtop #-}
  liftMtop ∷ ∀ m. (Monad m) ⇒ (∀ a. m a) → (∀ a. WriterT o m a)
  liftMtop mtopM = WriterT mtopM

instance (Monoid o,Monad m,MonadCont (o ∧ r) m) ⇒ MonadCont r (WriterT o m) where
  {-# INLINE callCC #-}
  callCC ∷ ∀ a. ((a → WriterT o m r) → WriterT o m r) → WriterT o m a
  callCC kk = WriterT $ callCC $ \ (k ∷ (o ∧ a) → m (o ∧ r)) →
    unWriterT $ kk $ \ (x ∷ a) → 
      WriterT $ k (null :* x)

  {-# INLINE withC #-}
  withC ∷ ∀ a. (a → WriterT o m r) → WriterT o m a → WriterT o m r
  withC k xM = WriterT $ 
    withC 
    (\ (o₁ :* x ∷ o ∧ a) → do 
         (o₂ :* r) ← unWriterT (k x) 
         return ((o₁ ⧺ o₂) :* r)
    )
    (unWriterT xM)

-----------
-- STATE --
-----------

instance LiftIO (StateT s) where
  {-# INLINE liftIO #-}
  liftIO ∷ ∀ m. (Monad m) ⇒ (∀ a. IO a → m a) → (∀ a. IO a → StateT s m a)
  liftIO ioM xM = StateT $ \ s → do
    x ← ioM xM
    return (s :* x)

instance LiftReader (StateT s) where
  {-# INLINE liftAsk #-}
  liftAsk ∷ ∀ m r. (Monad m) ⇒ m r → StateT s m r
  liftAsk askM = StateT $ \ s → do
    r ← askM
    return (s :* r)

  {-# INLINE liftLocal #-}
  liftLocal ∷ ∀ m r. (Monad m) ⇒ (∀ a. r → m a → m a) → (∀ a. r → StateT s m a → StateT s m a)
  liftLocal localM r xM = StateT $ \ s → localM r $ unStateT xM s

instance LiftWriter (StateT s) where
  {-# INLINE liftTell #-}
  liftTell ∷ ∀ m o. (Monad m) ⇒ (o → m ()) → (o → StateT s m ())
  liftTell tellM o = StateT $ \ s → do
    tellM o
    return (s :* ())

  {-# INLINE liftHijack #-}
  liftHijack ∷ ∀ m o. (Monad m) ⇒ (∀ a. m a → m (o ∧ a)) → (∀ a. StateT s m a → StateT s m (o ∧ a))
  liftHijack hijackM xM = StateT $ \ s → do
    (o :* (s' :* x)) ← hijackM $ unStateT xM s
    return (s' :* (o :* x))

instance LiftState (StateT s) where
  {-# INLINE liftGet #-}
  liftGet ∷ ∀ m s'. (Monad m) ⇒ m s' → StateT s m s'
  liftGet getM = StateT $ \ s → do
    s' ← getM
    return (s :* s')

  {-# INLINE liftPut #-}
  liftPut ∷ ∀ m s'. (Monad m) ⇒ (s' → m ()) → s' → StateT s m ()
  liftPut putM s' = StateT $ \ s → do
    putM s'
    return (s :* ())

instance LiftFail (StateT s) where
  {-# INLINE liftAbort #-}
  liftAbort ∷ ∀ m. (Monad m) ⇒ (∀ a. m a) → (∀ a. StateT s m a)
  liftAbort abortM = StateT $ \ _ → abortM

  {-# INLINE liftTry #-}
  liftTry ∷ ∀ m. (Monad m) ⇒ (∀ a. m a → m a → m a) → (∀ a. StateT s m a → StateT s m a → StateT s m a)
  liftTry tryM xM₁ xM₂ = StateT $ \ s → tryM (unStateT xM₁ s) (unStateT xM₂ s)

instance LiftError (StateT s) where
  {-# INLINE liftThrow #-}
  liftThrow ∷ ∀ m e. (Monad m) ⇒ (∀ a. e → m a) → (∀ a. e → StateT s m a)
  liftThrow throwM e = StateT $ \ _ → throwM e

  {-# INLINE liftCatch #-}
  liftCatch ∷ ∀ m e. (Monad m) ⇒ (∀ a. m a → (e → m a) → m a) → (∀ a. StateT s m a → (e → StateT s m a) → StateT s m a)
  liftCatch catchM xM k = StateT $ \ s → catchM (unStateT xM s) (\ e → unStateT (k e) s)

instance LiftNondet (StateT s) where
  {-# INLINE liftMzero #-}
  liftMzero ∷ ∀ m. (Monad m) ⇒ (∀ a. m a) → (∀ a. StateT s m a)
  liftMzero mzeroM = StateT $ \ _ → mzeroM

  {-# INLINE liftMplus #-}
  liftMplus ∷ ∀ m. (Monad m) ⇒ (∀ a. m a → m a → m a) → (∀ a. StateT s m a → StateT s m a → StateT s m a)
  liftMplus mplusM xM₁ xM₂ = StateT $ \ s → mplusM (unStateT xM₁ s) (unStateT xM₂ s)

instance LiftTop (StateT s) where
  {-# INLINE liftMtop #-}
  liftMtop ∷ ∀ m. (Monad m) ⇒ (∀ a. m a) → (∀ a. StateT s m a)
  liftMtop mtopM = StateT $ \ _ → mtopM

instance (Monad m,MonadCont (s ∧ r) m) ⇒ MonadCont r (StateT s m) where
  {-# INLINE callCC #-}
  callCC ∷ ∀ a. ((a → StateT s m r) → StateT s m r) → StateT s m a
  callCC kk = StateT $ \ s₁ → 
    callCC $ \ (k ∷ (s ∧ a) → m (s ∧ r)) →
      runStateT s₁ $ kk $ \ (x ∷ a) → 
        StateT $ \ s₂ →
          k (s₂ :* x)

  {-# INLINE withC #-}
  withC ∷ ∀ a. (a → StateT s m r) → StateT s m a → StateT s m r
  withC k xM = StateT $ \ s₁ →
    withC 
    (\ (s₂ :* x ∷ s ∧ a) → runStateT s₂ (k x))
    (runStateT s₁ xM)

----------
-- FAIL --
----------

instance LiftIO FailT where
  {-# INLINE liftIO #-}
  liftIO ∷ ∀ m. (Monad m) ⇒ (∀ a. IO a → m a) → (∀ a. IO a → FailT m a)
  liftIO ioM xM = FailT $ do
    x ← ioM xM
    return $ Some x

instance LiftReader FailT where
  {-# INLINE liftAsk #-}
  liftAsk ∷ ∀ m r. (Monad m) ⇒ m r → FailT m r
  liftAsk askM = FailT $ do
    r ← askM
    return $ Some r

  {-# INLINE liftLocal #-}
  liftLocal ∷ ∀ m r. (Monad m) ⇒ (∀ a. r → m a → m a) → (∀ a. r → FailT m a → FailT m a)
  liftLocal localM r xM = FailT $ localM r $ unFailT xM

instance LiftWriter FailT where
  {-# INLINE liftTell #-}
  liftTell ∷ ∀ m o. (Monad m) ⇒ (o → m ()) → (o → FailT m ())
  liftTell tellM o = FailT $ do
    tellM o
    return $ Some ()

  {-# INLINE liftHijack #-}
  liftHijack ∷ ∀ m o. (Monad m) ⇒ (∀ a. m a → m (o ∧ a)) → (∀ a. FailT m a → FailT m (o ∧ a))
  liftHijack hijackM xM = FailT $ do
    (o :* xO) ← hijackM $ unFailT xM
    case xO of
      None → return None
      Some x → return $ Some (o :* x)

instance LiftState FailT where
  {-# INLINE liftGet #-}
  liftGet ∷ ∀ m s. (Monad m) ⇒ m s → FailT m s
  liftGet getM = FailT $ do
    s ← getM
    return $ Some s

  {-# INLINE liftPut #-}
  liftPut ∷ ∀ m s. (Monad m) ⇒ (s → m ()) → (s → FailT m ())
  liftPut putM s = FailT $ do
    putM s
    return $ Some ()

instance LiftFail FailT where
  {-# INLINE liftAbort #-}
  liftAbort ∷ ∀ m. (Monad m) ⇒ (∀ a. m a) → (∀ a. FailT m a)
  liftAbort abortM = FailT $ abortM

  {-# INLINE liftTry #-}
  liftTry ∷ ∀ m. (Monad m) ⇒ (∀ a. m a → m a → m a) → (∀ a. FailT m a → FailT m a → FailT m a)
  liftTry tryM xM₁ xM₂ = FailT $ tryM (unFailT xM₁) (unFailT xM₂)

instance LiftError FailT where
  {-# INLINE liftThrow #-}
  liftThrow ∷ ∀ e m. (Monad m) ⇒ (∀ a. e → m a) → (∀ a. e → FailT m a)
  liftThrow throwM e = FailT $ throwM e
    
  {-# INLINE liftCatch #-}
  liftCatch ∷ ∀ e m. (Monad m) ⇒ (∀ a. m a → (e → m a) → m a) → (∀ a. FailT m a → (e → FailT m a) → FailT m a)
  liftCatch catchM xM k = FailT $ catchM (unFailT xM) $ \ e → unFailT $ k e

instance LiftNondet FailT where
  {-# INLINE liftMzero #-}
  liftMzero ∷ ∀ m. (Monad m) ⇒ (∀ a. m a) → (∀ a. FailT m a)
  liftMzero mzeroM = FailT $ mzeroM

  {-# INLINE liftMplus #-}
  liftMplus ∷ ∀ m. (Monad m) ⇒ (∀ a. m a → m a → m a) → (∀ a. FailT m a → FailT m a → FailT m a)
  liftMplus mplusM xM₁ xM₂ = FailT $ mplusM (unFailT xM₁) (unFailT xM₂)

instance LiftTop FailT where
  {-# INLINE liftMtop #-}
  liftMtop ∷ ∀ m. (Monad m) ⇒ (∀ a. m a) → (∀ a. FailT m a)
  liftMtop mtopM = FailT $ mtopM

instance (Monad m,MonadCont (𝑂 r) m) ⇒ MonadCont r (FailT m) where
  {-# INLINE callCC #-}
  callCC ∷ ∀ a. ((a → FailT m r) → FailT m r) → FailT m a
  callCC kk = FailT $
    callCC $ \ (k ∷ 𝑂 a → m (𝑂 r)) →
      unFailT $ kk $ \ (x ∷ a) → 
        FailT $ k (Some x)

  {-# INLINE withC #-}
  withC ∷ ∀ a. (a → FailT m r) → FailT m a → FailT m r
  withC k xM = FailT $
    withC 
    (\ (xO ∷ 𝑂 a) → case xO of
         None → return None
         Some x → unFailT $ k x)
    (unFailT xM)

-----------
-- Error --
-----------

instance LiftIO (ErrorT e) where
  {-# INLINE liftIO #-}
  liftIO ∷ ∀ m. (Monad m) ⇒ (∀ a. IO a → m a) → (∀ a. IO a → ErrorT e m a)
  liftIO ioM xM = ErrorT $ do
    x ← ioM xM
    return $ Inr x

instance LiftReader (ErrorT e) where
  {-# INLINE liftAsk #-}
  liftAsk ∷ ∀ m r. (Monad m) ⇒ m r → ErrorT e m r
  liftAsk askM = ErrorT $ do
    r ← askM
    return $ Inr r

  {-# INLINE liftLocal #-}
  liftLocal ∷ ∀ m r. (Monad m) ⇒ (∀ a. r → m a → m a) → (∀ a. r → ErrorT e m a → ErrorT e m a)
  liftLocal localM r xM = ErrorT $ localM r $ unErrorT xM

instance LiftWriter (ErrorT e) where
  {-# INLINE liftTell #-}
  liftTell ∷ ∀ m o. (Monad m) ⇒ (o → m ()) → (o → ErrorT e m ())
  liftTell tellM o = ErrorT $ do
    tellM o
    return $ Inr ()

  {-# INLINE liftHijack #-}
  liftHijack ∷ ∀ m o. (Monad m) ⇒ (∀ a. m a → m (o ∧ a)) → (∀ a. ErrorT e m a → ErrorT e m (o ∧ a))
  liftHijack hijackM xM = ErrorT $ do
    (o :* xE) ← hijackM $ unErrorT xM
    case xE of
      Inl e → return $ Inl e
      Inr x → return $ Inr (o :* x)

instance LiftState (ErrorT e) where
  {-# INLINE liftGet #-}
  liftGet ∷ ∀ m s. (Monad m) ⇒ m s → ErrorT e m s
  liftGet getM = ErrorT $ do
    s ← getM
    return $ Inr s

  {-# INLINE liftPut #-}
  liftPut ∷ ∀ m s. (Monad m) ⇒ (s → m ()) → (s → ErrorT e m ())
  liftPut putM s = ErrorT $ do
    putM s
    return $ Inr ()

instance LiftFail (ErrorT e) where
  {-# INLINE liftAbort #-}
  liftAbort ∷ ∀ m. (Monad m) ⇒ (∀ a. m a) → (∀ a. ErrorT e m a)
  liftAbort abortM = ErrorT $ abortM

  {-# INLINE liftTry #-}
  liftTry ∷ ∀ m. (Monad m) ⇒ (∀ a. m a → m a → m a) → (∀ a. ErrorT e m a → ErrorT e m a → ErrorT e m a)
  liftTry tryM xM₁ xM₂ = ErrorT $ tryM (unErrorT xM₁) (unErrorT xM₂)

instance LiftError (ErrorT e) where
  {-# INLINE liftThrow #-}
  liftThrow ∷ ∀ e' m. (Monad m) ⇒ (∀ a. e' → m a) → (∀ a. e' → ErrorT e m a)
  liftThrow throwM e = ErrorT $ throwM e
    
  {-# INLINE liftCatch #-}
  liftCatch ∷ ∀ e' m. (Monad m) ⇒ (∀ a. m a → (e' → m a) → m a) → (∀ a. ErrorT e m a → (e' → ErrorT e m a) → ErrorT e m a)
  liftCatch catchM xM k = ErrorT $ catchM (unErrorT xM) $ \ e → unErrorT $ k e

instance LiftNondet (ErrorT e) where
  {-# INLINE liftMzero #-}
  liftMzero ∷ ∀ m. (Monad m) ⇒ (∀ a. m a) → (∀ a. ErrorT e m a)
  liftMzero mzeroM = ErrorT $ mzeroM

  {-# INLINE liftMplus #-}
  liftMplus ∷ ∀ m. (Monad m) ⇒ (∀ a. m a → m a → m a) → (∀ a. ErrorT e m a → ErrorT e m a → ErrorT e m a)
  liftMplus mplusM xM₁ xM₂ = ErrorT $ mplusM (unErrorT xM₁) (unErrorT xM₂)

instance LiftTop (ErrorT e) where
  {-# INLINE liftMtop #-}
  liftMtop ∷ ∀ m. (Monad m) ⇒ (∀ a. m a) → (∀ a. ErrorT e m a)
  liftMtop mtopM = ErrorT $ mtopM

instance (Monad m,MonadCont (e ∨ r) m) ⇒ MonadCont r (ErrorT e m) where
  {-# INLINE callCC #-}
  callCC ∷ ∀ a. ((a → ErrorT e m r) → ErrorT e m r) → ErrorT e m a
  callCC kk = ErrorT $
    callCC $ \ (k ∷ e ∨ a → m (e ∨ r)) →
      unErrorT $ kk $ \ (x ∷ a) → 
        ErrorT $ k (Inr x)

  {-# INLINE withC #-}
  withC ∷ ∀ a. (a → ErrorT e m r) → ErrorT e m a → ErrorT e m r
  withC k xM = ErrorT $
    withC 
    (\ (ex ∷ e ∨ a) → case ex of
         Inl e → return $ Inl e
         Inr x → unErrorT $ k x)
    (unErrorT xM)

------------
-- NONDET --
------------

instance LiftIO NondetT where
  liftIO ∷ ∀ m. (Monad m) ⇒ (∀ a. IO a → m a) → (∀ a. IO a → NondetT m a)
  liftIO ioM xM = NondetT $ do
    x ← ioM xM
    return $ single x

instance LiftReader NondetT where
  liftAsk ∷ ∀ m r. (Monad m) ⇒ m r → NondetT m r
  liftAsk askM = NondetT $ do
    r ← askM
    return $ single r

  liftLocal ∷ ∀ m r. (Monad m) ⇒ (∀ a. r → m a → m a) → (∀ a. r → NondetT m a → NondetT m a)
  liftLocal localM r xM = NondetT $ localM r $ unNondetT xM
    
instance LiftWriter NondetT where
  liftTell ∷ ∀ m o. (Monad m) ⇒ (o → m ()) → (o → NondetT m ())
  liftTell tellM o = NondetT $ do
    tellM o
    return $ single ()

  liftHijack ∷ ∀ m o. (Monad m) ⇒ (∀ a. m a → m (o ∧ a)) → (∀ a. NondetT m a → NondetT m (o ∧ a))
  liftHijack hijackM xM = NondetT $ do
    (o :* xs) ← hijackM $ unNondetT xM
    return $ map (o :* ) xs

instance LiftState NondetT where
  liftGet ∷ ∀ m s. (Monad m) ⇒ m s → NondetT m s
  liftGet getM = NondetT $ do
    s ← getM
    return $ single s

  liftPut ∷ ∀ m s. (Monad m) ⇒ (s → m ()) → s → NondetT m ()
  liftPut putM s = NondetT $ do
    putM s
    return $ single ()

instance LiftFail NondetT where
  liftAbort ∷ ∀ m. (Monad m) ⇒ (∀ a. m a) → (∀ a. NondetT m a)
  liftAbort abortM = NondetT $ abortM

  liftTry ∷ ∀ m. (Monad m) ⇒ (∀ a. m a → m a → m a) → (∀ a. NondetT m a → NondetT m a → NondetT m a)
  liftTry tryM xM₁ xM₂ = NondetT $ tryM (unNondetT xM₁) (unNondetT xM₂)

instance LiftError NondetT where
  liftThrow ∷ ∀ m e. (Monad m) ⇒ (∀ a. e → m a) → (∀ a. e → NondetT m a)
  liftThrow throwM e = NondetT $ throwM e

  liftCatch ∷ ∀ m e. (Monad m) ⇒ (∀ a. m a → (e → m a) → m a) → (∀ a. NondetT m a → (e → NondetT m a) → NondetT m a)
  liftCatch catchM xM k = NondetT $ catchM (unNondetT xM) $ \ e → unNondetT $ k e

instance LiftNondet NondetT where
  liftMzero ∷ ∀ m. (Monad m) ⇒ (∀ a. m a) → (∀ a. NondetT m a)
  liftMzero mzeroM = NondetT $ mzeroM

  liftMplus ∷ ∀ m. (Monad m) ⇒ (∀ a. m a → m a → m a) → (∀ a. NondetT m a → NondetT m a → NondetT m a)
  liftMplus mplusM xM₁ xM₂ = NondetT $ mplusM (unNondetT xM₁) (unNondetT xM₂)

instance LiftTop NondetT where
  liftMtop ∷ ∀ m. (Monad m) ⇒ (∀ a. m a) → (∀ a. NondetT m a)
  liftMtop mtopM = NondetT $ mtopM

instance (Monad m,∀ a'. Monoid a' ⇒ Monoid (m a'),MonadCont (𝑄 r) m) ⇒ MonadCont r (NondetT m) where
  callCC ∷ ∀ a. ((a → NondetT m r) → NondetT m r) → NondetT m a
  callCC kk = NondetT $
    callCC $ \ (k ∷ 𝑄 a → m (𝑄 r)) →
      unNondetT $ kk $ \ (x ∷ a) → 
        NondetT $ k (single x)

  withC ∷ ∀ a. (a → NondetT m r) → NondetT m a → NondetT m r
  withC k xM = NondetT $
    withC 
    (\ (xs ∷ 𝑄 a) → unNondetT $ foldr mzero (⊞) $ map k $ iter xs)
    (unNondetT xM)

----------
-- Cont --
----------

instance LiftIO (ContT r) where
  liftIO ∷ ∀ m. (Monad m) ⇒ (∀ a. IO a → m a) → (∀ a. IO a → ContT r m a)
  liftIO ioM xM = ContT $ \ (k ∷ a → m r) → do
    x ← ioM xM
    k x

instance LiftReader (ContT r) where
  liftAsk ∷ ∀ m r'. (Monad m) ⇒ m r' → ContT r m r'
  liftAsk askM = ContT $ \ (k ∷ r' → m r) → k *$ askM

  liftLocal ∷ ∀ m r'. (Monad m) ⇒ (∀ a. r' → m a → m a) → (∀ a. r' → ContT r m a → ContT r m a)
  liftLocal localM r xM = ContT $ \ (k ∷ a → m r) → localM r $ unContT xM k

instance (Monad m,Monoid o,MonadWriter o m) ⇒ MonadWriter o (ContT (o ∧ r) m) where
  tell ∷ o → ContT (o ∧ r) m ()
  tell o = ContT $ \ (k ∷ () → m (o ∧ r)) → do
    tell o
    k ()
  hijack ∷ ∀ a. ContT (o ∧ r) m a → ContT (o ∧ r) m (o ∧ a)
  hijack xM = ContT $ \ (k ∷ (o ∧ a) → m (o ∧ r)) → do
    (o₂ :* (o₁ :* r)) ← hijack $ unContT xM (\ (x ∷ a) → k (null :* x))
    return ((o₁ ⧺ o₂) :* r)

instance (Monad m,MonadState s m) ⇒ MonadState s (ContT (s ∧ r) m) where
  get ∷ ContT (s ∧ r) m s
  get = ContT $ \ (k ∷ s → m (s ∧ r)) → do
    s ← get
    k s

  put ∷ s → ContT (s ∧ r) m ()
  put s = ContT $ \ (k ∷ () → m (s ∧ r)) → do
    put s
    k ()

instance (Monad m,MonadFail m) ⇒ MonadFail (ContT (𝑂 r) m) where
  abort ∷ ∀ a. ContT (𝑂 r) m a
  abort = ContT $ \ (_ ∷ a → m (𝑂 r)) → abort

  (⎅) ∷ ∀ a. ContT (𝑂 r) m a → ContT (𝑂 r) m a → ContT (𝑂 r) m a
  xM₁ ⎅ xM₂ = ContT $ \ (k ∷ a → m (𝑂 r)) → do
    rO ← unContT xM₁ k
    case rO of
      Some r → return $ Some r
      None → unContT xM₂ k

instance (Monad m,MonadError e m) ⇒ MonadError e (ContT (e ∨ r) m) where
  throw ∷ ∀ a. e → ContT (e ∨ r) m a
  throw e = ContT $ \ (_ ∷ a → m (e ∨ r)) → throw e

  catch ∷ ∀ a. ContT (e ∨ r) m a → (e → ContT (e ∨ r) m a) → ContT (e ∨ r) m a
  catch xM₁ kk = ContT $ \ (k ∷ a → m (e ∨ r)) → do
    ex ← unContT xM₁ k
    case ex of
      Inr r → return $ Inr r
      Inl e → unContT (kk e) k

instance (Monad m,MonadNondet m) ⇒ MonadNondet (ContT r m) where
  mzero ∷ ∀ a. ContT r m a
  mzero = ContT $ \ (_ ∷ a → m r) → mzero

  (⊞) ∷ ∀ a. ContT r m a → ContT r m a → ContT r m a
  xM₁ ⊞ xM₂ = ContT $ \ (k ∷ a → m r) → do
    unContT xM₁ k ⊞ unContT xM₂ k

instance (Monad m,MonadTop m) ⇒ MonadTop (ContT r m) where
  mtop ∷ ∀ a. ContT r m a
  mtop = ContT $ \ (_ ∷ a → m r) → mtop

-- ======= --
-- DERIVED --
-- ======= --

----------
-- RWST --
----------

newtype RWST r o s m a = RWST { unRWST ∷ ReaderT r (WriterT o (StateT s m)) a }
  deriving
  (Functor,Return,Bind,Monad
  ,MonadIO
  ,MonadReader r,MonadWriter o,MonadState s
  ,MonadFail,MonadError e
  ,MonadNondet,MonadTop)

{-# INLINE mkRWST #-}
mkRWST ∷ ∀ r o s m a. (Monad m) ⇒ (r → s → m (s ∧ o ∧ a)) → RWST r o s m a
mkRWST f = RWST $ ReaderT $ \ r → WriterT $ StateT $ \ s → do
  (s' :* o :* a) ← f r s
  return (s' :* (o :* a))

{-# INLINE runRWST #-}
runRWST ∷ ∀ r o s m a. (Monad m) ⇒ r → s → RWST r o s m a → m (s ∧ o ∧ a)
runRWST r s xM = do
  (s' :* (o :* a)) ← unStateT (unWriterT (unReaderT (unRWST xM) r)) s
  return (s' :* o :* a)

{-# INLINE evalRWST #-}
evalRWST ∷ ∀ r o s m a. (Monad m) ⇒ r → s → RWST r o s m a → m a
evalRWST r s = map snd ∘ runRWST r s

instance (Monoid o) ⇒ Functor2 (RWST r o s) where
  {-# INLINE map2 #-}
  map2 ∷ ∀ f₁ f₂. (∀ a. f₁ a → f₂ a) → (∀ a. RWST r o s f₁ a → RWST r o s f₂ a)
  map2 f = RWST ∘ map2 (map2 (map2 f)) ∘ unRWST

instance (RWST r o s) ⇄⁼ (ReaderT r ⊡ WriterT o ⊡ StateT s) where
  {-# INLINE isoto3 #-}
  isoto3 ∷ ∀ f a. RWST r o s f a → (ReaderT r ⊡ WriterT o ⊡ StateT s) f a
  isoto3 = Compose2 ∘ Compose2 ∘ unRWST

  {-# INLINE isofr3 #-}
  isofr3 ∷ ∀ f a. (ReaderT r ⊡ WriterT o ⊡ StateT s) f a → RWST r o s f a
  isofr3 = RWST ∘ unCompose2 ∘ unCompose2

deriving instance (Monoid o,Monad m,MonadCont (s ∧ (o ∧ r')) m) ⇒ MonadCont r' (RWST r o s m)

deriving instance (∀ a'. Null a' ⇒ Null (m a'),Null o,Null s,Null a) ⇒ Null (RWST r o s m a)
deriving instance (∀ a'. Append a' ⇒ Append (m a'),Append o,Append s,Append a) ⇒ Append (RWST r o s m a)
deriving instance 
  (∀ a'. Null a' ⇒ Null (m a')
  ,∀ a'. Append a' ⇒ Append (m a')
  ,∀ a'. Monoid a' ⇒ Monoid (m a')
  ,Monoid o,Monoid s,Monoid a) 
  ⇒ Monoid (RWST r o s m a)

type RWS r o s = RWST r o s ID

{-# INLINE mkRWS #-}
mkRWS ∷ ∀ r o s a. (r → s → (s ∧ o ∧ a)) → RWS r o s a
mkRWS f = mkRWST (\ r s → ID $ f r s)

{-# INLINE runRWS #-}
runRWS ∷ ∀ r o s a. r → s → RWS r o s a → s ∧ o ∧ a
runRWS r s xM = unID $ runRWST r s xM

{-# INLINE evalRWS #-}
evalRWS ∷ ∀ r o s a. r → s → RWS r o s a → a
evalRWS r s xM = unID $ evalRWST r s xM

