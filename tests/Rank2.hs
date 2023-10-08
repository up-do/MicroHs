module Rank2(main) where
import Prelude

f :: (forall a . a -> a) -> (Int, Bool)
f i = (i 1, i True)

g :: (forall a . a -> Int -> a) -> (Int, Bool)
g c = (c 1 1, c True 1)

data Id = Id (forall a . a -> a)

iD :: Id
iD = Id (\ x -> x)

main :: IO ()
main = do
  putStrLn $ showPair showInt showBool $ f id
  putStrLn $ showPair showInt showBool $ g const
  case iD of
    Id i -> putStrLn $ showPair showInt showBool (i 1, i True)
