{-# LANGUAGE DataKinds                 #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE FlexibleContexts          #-}
{-# LANGUAGE FlexibleInstances         #-}
{-# LANGUAGE KindSignatures            #-}
{-# LANGUAGE MagicHash                 #-}
{-# LANGUAGE MultiParamTypeClasses     #-}
{-# LANGUAGE PolyKinds                 #-}
{-# LANGUAGE ScopedTypeVariables       #-}
{-# LANGUAGE TypeApplications          #-}
{-# LANGUAGE TypeFamilies              #-}
{-# LANGUAGE TypeInType                #-}
{-# LANGUAGE TypeOperators             #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Numeric.DataFrame.IO
-- Copyright   :  (c) Artem Chirkin
-- License     :  BSD3
--
-- Maintainer  :  chirkin@arch.ethz.ch
--
-- Mutable DataFrames living in IO.
--
-----------------------------------------------------------------------------

module Numeric.DataFrame.IO
    ( IODataFrame (XIOFrame), SomeIODataFrame (..)
    , newDataFrame, newPinnedDataFrame
    , copyDataFrame, copyMutableDataFrame
    , freezeDataFrame, unsafeFreezeDataFrame
    , thawDataFrame, thawPinDataFrame, unsafeThawDataFrame
    , writeDataFrame, writeDataFrameOff
    , readDataFrame, readDataFrameOff
    , withDataFramePtr, isDataFramePinned
    ) where


import           GHC.Base
import           GHC.IO                                 (IO (..))
import           GHC.Ptr                                (Ptr (..))

import           Numeric.DataFrame.Family
import           Numeric.DataFrame.Internal.Array.Class
import           Numeric.DataFrame.Internal.Mutable
import           Numeric.Dimensions
import           Numeric.PrimBytes


-- | Mutable DataFrame that lives in IO.
--   Internal representation is always a MutableByteArray.
data family IODataFrame (t :: Type) (ns :: [k])

-- | Pure wrapper on a mutable byte array
newtype instance IODataFrame t (ns :: [Nat]) = IODataFrame (MDataFrame RealWorld t (ns :: [Nat]))

-- | Data frame with some dimensions missing at compile time.
--   Pattern-match against its constructor to get a Nat-indexed mutable data frame.
data instance IODataFrame t (xs :: [XNat])
  = forall (ns :: [Nat]) . Dimensions ns
  => XIOFrame (IODataFrame t ns)

-- | Mutable DataFrame of unknown dimensionality
data SomeIODataFrame (t :: Type)
  = forall (ns :: [Nat]) . Dimensions ns => SomeIODataFrame (IODataFrame t ns)

-- | Create a new mutable DataFrame.
newDataFrame :: forall t (ns :: [Nat])
              . ( PrimBytes t, Dimensions ns)
             => IO (IODataFrame t ns)
newDataFrame = IODataFrame <$> IO (newDataFrame# @t @ns)
{-# INLINE newDataFrame #-}


-- | Create a new mutable DataFrame.
newPinnedDataFrame :: forall t (ns :: [Nat])
                    . ( PrimBytes t, Dimensions ns)
                   => IO (IODataFrame t ns)
newPinnedDataFrame = IODataFrame <$> IO (newPinnedDataFrame# @t @ns)
{-# INLINE newPinnedDataFrame #-}


-- | Copy one DataFrame into another mutable DataFrame at specified position.
copyDataFrame :: forall (t :: Type) (as :: [Nat]) (b' :: Nat) (b :: Nat)
                                    (bs :: [Nat]) (asbs :: [Nat])
               . ( PrimBytes t
                 , PrimBytes (DataFrame t (as +: b'))
                 , ConcatList as (b :+ bs) asbs
                 , Dimensions (b :+ bs)
                 )
               => DataFrame t (as +: b') -> Idxs (b :+ bs) -> IODataFrame t asbs -> IO ()
copyDataFrame df ei (IODataFrame mdf) = IO (copyDataFrame# df ei mdf)
{-# INLINE copyDataFrame #-}

-- | Copy one mutable DataFrame into another mutable DataFrame at specified position.
copyMutableDataFrame :: forall (t :: Type) (as :: [Nat]) (b' :: Nat) (b :: Nat)
                               (bs :: [Nat]) (asbs :: [Nat])
                      . ( PrimBytes t
                        , ConcatList as (b :+ bs) asbs
                        , Dimensions (b :+ bs)
                        )
                     => IODataFrame t (as +: b') -> Idxs (b :+ bs)
                     -> IODataFrame t asbs -> IO ()
copyMutableDataFrame (IODataFrame mdfA) ei (IODataFrame mdfB)
    = IO (copyMDataFrame# mdfA ei mdfB)
{-# INLINE copyMutableDataFrame #-}


-- | Make a mutable DataFrame immutable, without copying.
unsafeFreezeDataFrame :: forall (t :: Type) (ns :: [Nat])
                       . PrimArray t (DataFrame t ns)
                      => IODataFrame t ns -> IO (DataFrame t ns)
unsafeFreezeDataFrame (IODataFrame mdf) = IO (unsafeFreezeDataFrame# mdf)
{-# INLINE unsafeFreezeDataFrame #-}


-- | Copy content of a mutable DataFrame into a new immutable DataFrame.
freezeDataFrame :: forall (t :: Type) (ns :: [Nat])
                 . PrimArray t (DataFrame t ns)
                => IODataFrame t ns -> IO (DataFrame t ns)
freezeDataFrame (IODataFrame mdf) = IO (freezeDataFrame# mdf)
{-# INLINE freezeDataFrame #-}

-- | Create a new mutable DataFrame and copy content of immutable one in there.
thawDataFrame :: forall (t :: Type) (ns :: [Nat])
               . (PrimBytes (DataFrame t ns), PrimBytes t)
              => DataFrame t ns -> IO (IODataFrame t ns)
thawDataFrame df = IODataFrame <$> IO (thawDataFrame# df)
{-# INLINE thawDataFrame #-}

-- | Create a new mutable DataFrame and copy content of immutable one in there.
--   The result array is pinned and aligned.
thawPinDataFrame :: forall (t :: Type) (ns :: [Nat])
                  . (PrimBytes (DataFrame t ns), PrimBytes t)
                 => DataFrame t ns -> IO (IODataFrame t ns)
thawPinDataFrame df = IODataFrame <$> IO (thawPinDataFrame# df)
{-# INLINE thawPinDataFrame #-}

-- | UnsafeCoerces an underlying byte array.
unsafeThawDataFrame :: forall (t :: Type) (ns :: [Nat])
                     . (PrimBytes (DataFrame t ns), PrimBytes t)
                    => DataFrame t ns -> IO (IODataFrame t ns)
unsafeThawDataFrame df = IODataFrame <$> IO (unsafeThawDataFrame# df)
{-# INLINE unsafeThawDataFrame #-}


-- | Write a single element at the specified index
writeDataFrame :: forall t (ns :: [Nat])
                . ( PrimBytes t, Dimensions ns )
               => IODataFrame t ns -> Idxs ns -> DataFrame t ('[] :: [Nat]) -> IO ()
writeDataFrame (IODataFrame mdf) ei = IO . writeDataFrame# mdf ei . unsafeCoerce#
{-# INLINE writeDataFrame #-}


-- | Read a single element at the specified index
readDataFrame :: forall (t :: Type) (ns :: [Nat])
               . ( PrimBytes t, Dimensions ns )
              => IODataFrame t ns -> Idxs ns -> IO (DataFrame t ('[] :: [Nat]))
readDataFrame (IODataFrame mdf) = unsafeCoerce# . IO . readDataFrame# mdf
{-# INLINE readDataFrame #-}


-- | Write a single element at the specified element offset
writeDataFrameOff :: forall (t :: Type) (ns :: [Nat])
                   . PrimBytes t
               => IODataFrame t ns -> Int -> DataFrame t ('[] :: [Nat])  -> IO ()
writeDataFrameOff (IODataFrame mdf) (I# i)
  = IO . writeDataFrameOff# mdf i . unsafeCoerce#
{-# INLINE writeDataFrameOff #-}


-- | Read a single element at the specified element offset
readDataFrameOff :: forall (t :: Type) (ns :: [Nat])
                  . PrimBytes t
               => IODataFrame t ns -> Int -> IO (DataFrame t ('[] :: [Nat]))
readDataFrameOff (IODataFrame mdf) (I# i)
  = unsafeCoerce# (IO (readDataFrameOff# mdf i))
{-# INLINE readDataFrameOff #-}


-- | Allow arbitrary IO operations on a pointer to the beginning of the data
--   keeping the data from garbage collecting until the arg function returns.
--
--   Warning: do not let @Ptr t@ leave the scope of the arg function,
--            the data may be garbage-collected by then.
--
--   Warning: use this function on a pinned DataFrame only;
--            otherwise, the data may be relocated before the arg fun finishes.
withDataFramePtr :: forall (t :: Type) (ns :: [k]) (r :: Type)
                  . (PrimBytes t, KnownDimKind k)
                 => IODataFrame t ns
                 -> ( Ptr t -> IO r )
                 -> IO r
withDataFramePtr df k = case dimKind @k of
    DimNat -> case df of
      IODataFrame x
        -> IO $ withDataFramePtr# x (\p -> case k (Ptr p) of IO f -> f)
    DimXNat -> case df of
      XIOFrame (IODataFrame x)
        -> IO $ withDataFramePtr# x (\p -> case k (Ptr p) of IO f -> f)


-- | Check if the byte array wrapped by this DataFrame is pinned,
--   which means cannot be relocated by GC.
isDataFramePinned :: forall (t :: Type) (ns :: [k])
                   . KnownDimKind k
                  => IODataFrame t ns -> Bool
isDataFramePinned df = case dimKind @k of
    DimNat -> case df of
      IODataFrame x -> isDataFramePinned# x
    DimXNat -> case df of
      XIOFrame (IODataFrame x) -> isDataFramePinned# x
