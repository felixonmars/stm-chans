{-# OPTIONS_GHC -fno-warn-name-shadowing #-}
{-# LANGUAGE CPP, DeriveDataTypeable #-}

#if __GLASGOW_HASKELL__ >= 701
{-# LANGUAGE Trustworthy #-}
#endif

----------------------------------------------------------------
--                                                    2012.02.29
-- |
-- Module      :  Control.Concurrent.STM.TQueue.Compat
-- Copyright   :  Copyright (c) 2011--2012 wren ng thornton
-- License     :  BSD
-- Maintainer  :  wren@community.haskell.org
-- Stability   :  provisional
-- Portability :  non-portable (STM, CPP)
--
-- Compatibility layer for older versions of the @stm@ library.
-- Namely, we copy "Control.Concurrent.STM.TQueue" module which @stm<2.4.0@
-- lacks. This module uses Cabal-style CPP macros in order to use the package
-- versions when available.
--
-- /Since: 1.3.2/
----------------------------------------------------------------

module Control.Concurrent.STM.TQueue.Compat (
        -- * TQueue
    TQueue,
    newTQueue,
    newTQueueIO,
    readTQueue,
    tryReadTQueue,
    peekTQueue,
    tryPeekTQueue,
    writeTQueue,
        unGetTQueue,
        isEmptyTQueue,
  ) where
#if MIN_VERSION_stm(2,4,0)
import Control.Concurrent.STM.TQueue
#else
import GHC.Conc

import Data.Typeable (Typeable)

-- | 'TQueue' is an abstract type representing an unbounded FIFO channel.
data TQueue a = TQueue {-# UNPACK #-} !(TVar [a])
                       {-# UNPACK #-} !(TVar [a])
  deriving Typeable

instance Eq (TQueue a) where
  TQueue a _ == TQueue b _ = a == b

-- |Build and returns a new instance of 'TQueue'
newTQueue :: STM (TQueue a)
newTQueue = do
  read  <- newTVar []
  write <- newTVar []
  return (TQueue read write)

-- |@IO@ version of 'newTQueue'.  This is useful for creating top-level
-- 'TQueue's using 'System.IO.Unsafe.unsafePerformIO', because using
-- 'atomically' inside 'System.IO.Unsafe.unsafePerformIO' isn't
-- possible.
newTQueueIO :: IO (TQueue a)
newTQueueIO = do
  read  <- newTVarIO []
  write <- newTVarIO []
  return (TQueue read write)

-- |Write a value to a 'TQueue'.
writeTQueue :: TQueue a -> a -> STM ()
writeTQueue (TQueue _read write) a = do
  listend <- readTVar write
  writeTVar write (a:listend)

-- |Read the next value from the 'TQueue'.
readTQueue :: TQueue a -> STM a
readTQueue (TQueue read write) = do
  xs <- readTVar read
  case xs of
    (x:xs') -> do writeTVar read xs'
                  return x
    [] -> do ys <- readTVar write
             case ys of
               [] -> retry
               _  -> case reverse ys of
                       [] -> error "readTQueue"
                       (z:zs) -> do writeTVar write []
                                    writeTVar read zs
                                    return z

-- | A version of 'readTQueue' which does not retry. Instead it
-- returns @Nothing@ if no value is available.
tryReadTQueue :: TQueue a -> STM (Maybe a)
tryReadTQueue c = fmap Just (readTQueue c) `orElse` return Nothing

-- | Get the next value from the @TQueue@ without removing it,
-- retrying if the channel is empty.
peekTQueue :: TQueue a -> STM a
peekTQueue c = do
  x <- readTQueue c
  unGetTQueue c x
  return x

-- | A version of 'peekTQueue' which does not retry. Instead it
-- returns @Nothing@ if no value is available.
tryPeekTQueue :: TQueue a -> STM (Maybe a)
tryPeekTQueue c = do
  m <- tryReadTQueue c
  case m of
    Nothing -> return Nothing
    Just x  -> do
      unGetTQueue c x
      return m

-- |Put a data item back onto a channel, where it will be the next item read.
unGetTQueue :: TQueue a -> a -> STM ()
unGetTQueue (TQueue read _write) a = do
  xs <- readTVar read
  writeTVar read (a:xs)

-- |Returns 'True' if the supplied 'TQueue' is empty.
isEmptyTQueue :: TQueue a -> STM Bool
isEmptyTQueue (TQueue read write) = do
  xs <- readTVar read
  case xs of
    (_:_) -> return False
    [] -> do ys <- readTVar write
             case ys of
               [] -> return True
               _  -> return False
#endif
