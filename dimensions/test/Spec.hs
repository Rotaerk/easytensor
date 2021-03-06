module Main (tests, main) where

import           System.Exit
import           Distribution.TestSuite

import qualified Numeric.DimTest
import qualified Numeric.Dimensions.DimsTest


-- | Collection of tests in detailed-0.9 format
tests :: IO [Test]
tests = return
  [ test "Dim"    Numeric.DimTest.runTests
  , test "Dims"   Numeric.Dimensions.DimsTest.runTests
  ]




-- | Run tests as exitcode-stdio-1.0
main :: IO ()
main = do
    ts <- tests
    trs <- mapM (\(Test ti) ->(,) (name ti) <$> run ti) ts
    case filter (not . isGood) trs of
       [] -> exitSuccess
       xs -> do
        putStrLn $ "Failed tests: " ++ unwords (fmap fst xs)
        exitFailure
  where
    isGood (_, Finished Pass) = True
    isGood _ = False


-- | Convert QuickCheck props into Cabal tests
test :: String -> IO Bool -> Test
test tName propOp = Test testI
  where
    testI = TestInstance
        { run = fromBool <$> propOp
        , name = tName
        , tags = []
        , options = []
        , setOption = \_ _ -> Right testI
        }
    fromBool False = Finished (Fail "Property does not hold!")
    fromBool True  = Finished Pass
