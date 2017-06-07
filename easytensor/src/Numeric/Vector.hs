{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Numeric.Vector
-- Copyright   :  (c) Artem Chirkin
-- License     :  BSD3
--
-- Maintainer  :  chirkin@arch.ethz.ch
--
--
-----------------------------------------------------------------------------

module Numeric.Vector
    ( -- * Type aliases
      Vector
    , Vec2f, Vec3f, Vec4f, Vec2d, Vec3d, Vec4d
      -- * Common operations
    , (.*.), dot, (·)
    , normL1, normL2, normLPInf, normLNInf, normLP
    , vec2, vec3, vec4
    , det2, cross, (×)
    ) where

import GHC.TypeLits

import           Numeric.Dimensions
import qualified Numeric.Commons as NCommons
import           Numeric.DataFrame.Type

import           Numeric.Scalar

--------------------------------------------------------------------------------
-- * Vector type
--------------------------------------------------------------------------------

type Vector t (n :: Nat) = DataFrame t '[n]

type Vec2f = Vector Float 2
type Vec3f = Vector Float 3
type Vec4f = Vector Float 4
type Vec2d = Vector Double 2
type Vec3d = Vector Double 3
type Vec4d = Vector Double 4


-- | Scalar product -- sum of Vecs' components products,
--                     propagated into whole Vec
(.*.) :: ( Num t
         , Num (Vector t n)
         , NCommons.ElementWise (Idx '[n]) t (Vector t n)
         )
      => Vector t n -> Vector t n -> Vector t n
(.*.) a b = NCommons.broadcast . NCommons.ewfold (const (+)) 0 $ a * b
infixl 7 .*.

-- | Scalar product -- sum of Vecs' components products -- a scalar
dot :: ( Num t
       , Num (Vector t n)
       , NCommons.ElementWise (Idx '[n]) t (Vector t n)
       )
    => Vector t n -> Vector t n -> Scalar t
dot a b = scalar . NCommons.ewfold (const (+)) 0 $ a * b

-- | Dot product of two vectors
infixl 7 ·
(·) :: ( Num t
       , Num (Vector t n)
       , NCommons.ElementWise (Idx '[n]) t (Vector t n)
       )
    => Vector t n -> Vector t n -> Scalar t
(·) = dot
{-# INLINE (·) #-}


-- | Sum of absolute values
normL1 :: ( Num t
          , NCommons.ElementWise (Idx '[n]) t (Vector t n)
          )
       => Vector t n -> Scalar t
normL1 = scalar . NCommons.ewfold (const (\a -> (abs a +))) 0

-- | hypot function (square root of squares)
normL2 :: ( Floating t
          , NCommons.ElementWise (Idx '[n]) t (Vector t n)
          )
       => Vector t n -> Scalar t
normL2 = scalar . sqrt . NCommons.ewfold (const (\a -> (a*a +))) 0

-- | Maximum of absolute values
normLPInf :: ( Ord t, Num t
             , NCommons.ElementWise (Idx '[n]) t (Vector t n)
             )
          => Vector t n -> Scalar t
normLPInf = scalar . NCommons.ewfold (const (max . abs)) 0

-- | Minimum of absolute values
normLNInf :: ( Ord t, Num t
             , NCommons.ElementWise (Idx '[n]) t (Vector t n)
             )
          => Vector t n -> Scalar t
normLNInf x = scalar $ NCommons.ewfold (const (min . abs))
                                 (abs $ x NCommons.! (1 :! Z)) x

-- | Norm in Lp space
normLP :: ( Floating t
          , NCommons.ElementWise (Idx '[n]) t (Vector t n)
          )
       => Int -> Vector t n -> Scalar t
normLP i' = scalar . (**ri) . NCommons.ewfold (const (\a -> (a**i +))) 0
  where
    i  = fromIntegral i'
    ri = recip i
{-# INLINE [2] normLP #-}
{-# RULES
"normLP/L1" normLP 1 = normL1
"normLP/L2" normLP 2 = normL2
  #-}

-- | Compose a 2D vector
vec2 :: NCommons.ElementWise (Idx '[2]) t (Vector t 2) => t -> t -> Vector t 2
vec2 a b = NCommons.ewgen f
  where
    f (1 :! Z) = a
    f _ = b

-- | Take a determinant of a matrix composed from two 2D vectors.
--   Like a cross product in 2D.
det2 :: ( NCommons.ElementWise (Idx '[2]) t (Vector t 2)
        , Num t
        ) => Vector t 2 -> Vector t 2 -> Scalar t
det2 a b = scalar $ a NCommons.! (1 :! Z) * b NCommons.! (2 :! Z)
                     - a NCommons.! (2 :! Z) * b NCommons.! (1 :! Z)

-- | Compose a 3D vector
vec3 :: NCommons.ElementWise (Idx '[3]) t (Vector t 3) => t -> t -> t -> Vector t 3
vec3 a b c = NCommons.ewgen f
  where
    f (1 :! Z) = a
    f (2 :! Z) = b
    f _ = c

-- | Cross product
cross :: ( NCommons.ElementWise (Idx '[3]) t (Vector t 3)
         , Num t
         ) => Vector t 3 -> Vector t 3 -> Vector t 3
cross a b = vec3 ( a NCommons.! (2 :! Z) * b NCommons.! (3 :! Z)
                 - a NCommons.! (3 :! Z) * b NCommons.! (2 :! Z) )
                 ( a NCommons.! (3 :! Z) * b NCommons.! (1 :! Z)
                 - a NCommons.! (1 :! Z) * b NCommons.! (3 :! Z) )
                 ( a NCommons.! (1 :! Z) * b NCommons.! (2 :! Z)
                 - a NCommons.! (2 :! Z) * b NCommons.! (1 :! Z) )


-- | Cross product for two vectors in 3D
infixl 7 ×
(×) :: ( NCommons.ElementWise (Idx '[3]) t (Vector t 3)
       , Num t
        ) => Vector t 3 -> Vector t 3 -> Vector t 3
(×) = cross
{-# INLINE (×) #-}


-- | Compose a 3D vector
vec4 :: NCommons.ElementWise (Idx '[4]) t (Vector t 4)
     => t -> t -> t -> t -> Vector t 4
vec4 a b c d = NCommons.ewgen f
  where
    f (1 :! Z) = a
    f (2 :! Z) = b
    f (3 :! Z) = c
    f _ = d
