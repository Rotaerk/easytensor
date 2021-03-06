{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds       #-}
{-# LANGUAGE GADTs           #-}
{-# LANGUAGE KindSignatures  #-}
{-# LANGUAGE Rank2Types      #-}
{-# LANGUAGE PolyKinds       #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Numeric.Type.Evidence
-- Copyright   :  (c) Artem Chirkin
-- License     :  BSD3
--
-- Maintainer  :  chirkin@arch.ethz.ch
--
-- Construct type-level evidence at runtime
--
-----------------------------------------------------------------------------
module Numeric.Type.Evidence
  ( Evidence (..), withEvidence, sumEvs, (+!+)
  , Evidence' (..), toEvidence, toEvidence'
  ) where


import           GHC.Base (Type)
import           GHC.Exts (Constraint)


-- | Bring an instance of certain class or constaint satisfaction evidence into scope.
data Evidence :: Constraint -> Type where
    E :: a => Evidence a

-- | Combine evidence
sumEvs :: Evidence a -> Evidence b -> Evidence (a,b)
sumEvs E E = E
{-# INLINE sumEvs #-}

infixl 4 +!+
-- | Combine evidence
(+!+) :: Evidence a -> Evidence b -> Evidence (a,b)
(+!+) = sumEvs
{-# INLINE (+!+) #-}

-- | Pattern match agains evidence to get constraints info
withEvidence :: Evidence a -> (a => r) -> r
withEvidence d r = case d of E -> r
{-# INLINE withEvidence #-}

-- | Same as @Evidence@, but allows to separate constraint function from
--   the type it is applied to.
data Evidence' :: (k -> Constraint) -> k -> Type where
    E' :: c a => Evidence' c a

toEvidence :: Evidence' c a -> Evidence (c a)
toEvidence E' = E
{-# INLINE toEvidence #-}

toEvidence' :: Evidence (c a) -> Evidence' c a
toEvidence' E = E'
{-# INLINE toEvidence' #-}
