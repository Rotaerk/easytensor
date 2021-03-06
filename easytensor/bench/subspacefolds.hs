{-# LANGUAGE DataKinds        #-}
{-# LANGUAGE GADTs            #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeOperators    #-}

module Main (main) where

import           Data.Maybe (fromMaybe)
import           Data.Time.Clock

import           Numeric.DataFrame
import           Numeric.Dimensions


type DList = [6,4,10,7,35,8,12] -- [6,26,8,10,35,8,12]

main :: IO ()
main = do
    t0 <- getCurrentTime
    putStrLn $ "\nStarting benchmarks, current time is " ++ show t0
    let df = iwgen @Float @'[] @DList (fromIntegral . fromEnum)
    t1 <- df `seq` getCurrentTime
    seq t1 putStrLn $ "Created DataFrame, elapsed time is " ++ show (diffUTCTime t1 t0)

    putStrLn "\nRunning a ewfoldl on scalar elements..."
    let rezEwf = ewfoldl @Float @'[] @DList (\a x -> return $! fromMaybe x a + fromMaybe 0 a / (x+1)) (Just 1)  df
    t2 <- rezEwf `seq` getCurrentTime
    seq t2 putStrLn $ "Done; elapsed time = " ++ show (diffUTCTime t2 t1)
    print rezEwf

    putStrLn "\nRunning a iwfoldl on scalar elements (not using idx)..."
    let rezIwf = iwfoldl @Float @'[] @DList (\_ a x -> a +  a / (x+1)) 1 df
    t3 <- rezIwf `seq` getCurrentTime
    seq t3 putStrLn $ "Done; elapsed time = " ++ show (diffUTCTime t3 t2)
    print rezIwf

    putStrLn "\nRunning a iwfoldr on scalar elements (using fromEnum idx)..."
    let rezIwf2 = iwfoldr @Float @'[] @DList (\i x a -> return $! fromMaybe 0 a + x / ((1+) . fromIntegral $ fromEnum i)) (Just 0) df
    t4 <- rezIwf2 `seq` getCurrentTime
    seq t4 putStrLn $ "Done; elapsed time = " ++ show (diffUTCTime t4 t3)
    print rezIwf2

    putStrLn "\nRunning a iwfoldl on scalar elements (enforcing idx)..."
    let rezIwf3 = iwfoldl @Float @'[] @DList (\i a x -> i `seq` return $! fromMaybe 0 a + fromMaybe x a / (x+1)) (Just 1) df
    t5 <- rezIwf3 `seq` getCurrentTime
    seq t5 putStrLn $ "Done; elapsed time = " ++ show (diffUTCTime t5 t4)
    print rezIwf3

    putStrLn "\nRunning a ewfoldl on vector5 elements..."
    let rezEwv1 = ewfoldl @Float @'[Head DList] @(Tail DList)
                          (\a x -> return $! fromMaybe 2 a + fromMaybe 0 a / (1 + iwgen @_ @'[] (\(Idx i:*U) -> Idx (i+1) :* U !. x )) )
                          (Just (3 :: DataFrame Float '[5])) df
    t6 <- rezEwv1 `seq` getCurrentTime
    seq t6 putStrLn $ "Done; elapsed time = " ++ show (diffUTCTime t6 t5)
    print rezEwv1

    putStrLn "\nRunning a ewfoldr on vector3 elements..."
    let rezEwv2 = ewfoldr @Float @'[Head DList] @(Tail DList)
                          (\x a -> return $! fromMaybe 2 a + fromMaybe 1 a / (1 + iwgen @_ @'[] (\(Idx i:*U) -> Idx (i+1):* U !. x )))
                          (Just (3 :: DataFrame Float '[3])) df
    t7 <- rezEwv2 `seq` getCurrentTime
    seq t7 putStrLn $ "Done; elapsed time = " ++ show (diffUTCTime t7 t6)
    print rezEwv2

    putStrLn "\nRunning a ewfoldr with matrix products..."
    let rezEwm = ewfoldr @Float @(Take 3 DList) @(Drop 3 DList)
                          (\x a ->  a + x %* (1 <::> 0.5 <:> 0.1)  )
                          (1 :: DataFrame Float (Take 2 DList +: 3)) df
    t8 <- rezEwm `seq` getCurrentTime
    seq t8 putStrLn $ "Done; elapsed time = " ++ show (diffUTCTime t8 t7)
    print rezEwm




    putStrLn "Checking indexes"
    print $ 2:*1:*1:*3:*1:*U !. df
