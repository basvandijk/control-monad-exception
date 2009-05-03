{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE EmptyDataDecls #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE FlexibleInstances #-}
module Control.Monad.Exception.Class (
       module Control.Monad,
       MonadThrow(..), MonadCatch(..),
       Throws(..), Caught(..),
       WrapException(..), Exception(..), SomeException) where

import Control.Monad
import Control.Monad.Trans
import Control.Monad.Trans.Error
import Control.Monad.Trans.List
import Control.Monad.Trans.Reader
import Control.Monad.Trans.State
import Control.Monad.Trans.Writer
import Control.Monad.Trans.RWS
import Control.Exception (Exception(..), SomeException)
import qualified Control.Exception
import Data.Monoid
import Data.Typeable
import Prelude hiding (catch)

{-| @Throws@ is the mechanism used to keep a type level
    list of exceptions.
    .
    Usually there is no need for the user of this library
    to add further instances to @Throws@ except in one
    case: to encode subtyping. For instance if we have
    an @IOException@ type and a @FIleNotFoundException@ subcase,
    we need to add the instance:

 > instance Throws FileNotFoundException (Caught IOException l)

-}

class Exception e => Throws e s

class Monad m => MonadThrow e m where
    throw :: e -> m a

instance Exception e => MonadThrow e IO where
   throw = Control.Exception.throw

class (Monad m, Monad m') => MonadCatch e m m' | e m -> m', e m' -> m where
   catch   :: m a -> (e -> m' a) -> m' a

instance Exception e => MonadCatch e IO IO where
   catch   = Control.Exception.catch

-- | A type level witness of a exception handler.
data Caught e l

instance Exception e => Throws e (Caught e l)
instance Throws e l => Throws e (Caught e1 l)
-- | @SomeException@ is at the top of the exception hierarchy
--   .
--   Capturing SomeException captures every possible exception
instance Exception e => Throws e (Caught SomeException l)

-- Labelled SomeException
-- ------------------------
newtype WrapException l = WrapException {wrapException::SomeException} deriving Show


-- Throw and Catch instances for the Either and ErrorT monads
-- -----------------------------------------------------------
instance (Error e) => MonadThrow e (Either e) where throw = Left
instance (Error e) => MonadCatch e (Either e) (Either e) where catch m h = either h Right m

instance (Error e, Monad m) => MonadThrow e (ErrorT e m) where throw = throwError
instance (Error e, Monad m) => MonadCatch e (ErrorT e m) (ErrorT e m) where catch = catchError


-- Instances for transformers (requires undecidable instances in some cases)
-- -------------------------------------------------------------------------
instance MonadThrow e m    => MonadThrow e (ListT m)            where throw = lift . throw
instance MonadCatch e m m' => MonadCatch e (ListT m) (ListT m') where catch (ListT m) h = ListT (catch m (runListT . h))

instance MonadThrow e m    => MonadThrow e (ReaderT r m)                where throw = lift . throw
instance MonadCatch e m m' => MonadCatch e (ReaderT r m) (ReaderT r m') where catch (ReaderT m) h = ReaderT (\s -> catch (m s) ((`runReaderT` s) . h))

instance (Monoid w, MonadThrow e m)    => MonadThrow e (WriterT w  m)               where throw = lift . throw
instance (Monoid w, MonadCatch e m m') => MonadCatch e (WriterT w m) (WriterT w m') where catch (WriterT m) h = WriterT (catch m (runWriterT . h))

instance MonadThrow e m    => MonadThrow e (StateT s m)               where throw = lift . throw
instance MonadCatch e m m' => MonadCatch e (StateT s m) (StateT s m') where catch (StateT m) h = StateT (\s -> catch (m s) ((`runStateT` s) . h))

instance (Monoid w, MonadThrow e m)    => MonadThrow e (RWST r w s m)                 where throw = lift . throw
instance (Monoid w, MonadCatch e m m') => MonadCatch e (RWST r w s m) (RWST r w s m') where catch (RWST m) h = RWST (\r s -> catch (m r s) ((\m -> runRWST m r s) . h))
