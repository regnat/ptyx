{-|
Module: Types.Bdd
Description: Binary decision diagrams

A data structure to represent boolean formulas, with efficient operations of
union and intersection.
Used here to represents set-theoretic combinations of types.
|-}

{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NamedFieldPuns #-}

module Types.Bdd (
  T,
  atom, isTriviallyFull, isTriviallyEmpty,
  foldBdd, FoldParam(..),
  get,
  DNF, toDNF
  )
where

import Types.SetTheoretic

-- | A Binary decision diagram
data T a
    = Leaf Bool
    | Split { tif :: a, tthen :: T a, telse :: T a }
    deriving (Eq, Ord)

instance Show a => Show (T a) where
  show x
    | isTriviallyEmpty x = "⊥"
    | isTriviallyFull  x = "⊤"
    | otherwise          =
      foldBdd FoldParam{
        fpEmpty = "⊥",
        fpFull = "⊤",
        fpAtom = show,
        fpCup = \x y -> x ++ " | " ++ y,
        fpCap = \x y -> x ++ " & " ++ y,
        fpDiff = \x y -> x ++ " \\ " ++ y
      }
      x

-- | @atom x@ Returns the Bdd containing only the atom @x@
atom :: a -> T a
atom x = Split x (Leaf True) (Leaf False)

-- | Tell wether this is the trivial full Bdd
isTriviallyFull :: T a -> Bool
isTriviallyFull (Leaf True) = True
isTriviallyFull _ = False

-- | Tell wether this is the trivial empty Bdd
isTriviallyEmpty :: T a -> Bool
isTriviallyEmpty (Leaf False) = True
isTriviallyEmpty _ = False

-- | Parameters for the @foldBdd@ function.
-- The existence of this record is just a workaround around the fact that
-- haskell has no labeled arguments.
data FoldParam src target = FoldParam { fpEmpty :: target
                                        , fpFull :: target
                                        , fpCup :: target -> target -> target
                                        , fpCap :: target -> target -> target
                                        , fpDiff :: target -> target -> target
                                        , fpAtom :: src -> target
                                        }

-- | Recursively compute a value from a Bdd
foldBdd :: FoldParam a b -> T a -> b
foldBdd param bdd =
  case bdd of
    Leaf False -> fpEmpty param
    Leaf True -> fpFull param
    Split x p n ->
      let x' = fpAtom param x
          p' = fpCap param x' (foldBdd param p)
          n' = fpDiff param x' (foldBdd param n)
      in
      fpCup param p' n'

instance Ord a => SetTheoretic_ (T a) where
  empty = Leaf False
  full  = Leaf True

  cup (Leaf True) _ = Leaf True
  cup _ (Leaf True) = Leaf True
  cup a (Leaf False) = a
  cup (Leaf False) a = a
  cup b1 b2 =
    let (Split a1 c1 d1) = b1
        (Split a2 c2 d2) = b2
    in
    recurse cup b1 b2 a1 c1 d1 a2 c2 d2

  cap (Leaf False) _ = Leaf False
  cap _ (Leaf False) = Leaf False
  cap a (Leaf True)  = a
  cap (Leaf True) a  = a
  cap b1 b2 =
    let (Split a1 c1 d1) = b1
        (Split a2 c2 d2) = b2
    in
    recurse cap b1 b2 a1 c1 d1 a2 c2 d2

  diff (Leaf False) _ = Leaf False
  diff _ (Leaf True)  = Leaf False
  diff a (Leaf False) = a
  diff (Leaf True) (Split a c d) =
    Split a (diff (Leaf True) c) (diff (Leaf True) d)
  diff b1 b2 =
    let (Split a1 c1 d1) = b1
        (Split a2 c2 d2) = b2
    in
    recurse diff b1 b2 a1 c1 d1 a2 c2 d2

recurse :: Ord a => (t1 -> t -> T a) -> t1 -> t -> a -> t1 -> t1 -> a -> t -> t -> T a
recurse op b1 b2 a1 c1 d1 a2 c2 d2 =
  case () of _
              | a1 == a2 -> Split a1 (op c1 c2) (op d1 d2)
              | a1 < a2 -> Split a1 (op c1 b2) (op d1 b2)
              | otherwise -> Split a2 (op b1 c2) (op b1 d2)

-- | Returns a DNF formula from a Bdd
--
-- The outer list represents a union, and each element is the intersection of
-- its sub-elements, where the first component is the list of positive atoms
-- and the second the list of negative atoms.
-- For example, @[ ([x], []), ([y], [z, q]) ]@ represents the formula
--
-- > x \/ (y /\ (not z) /\ (not q))
get :: T a -> [([a], [a])]
get a = get_aux a [] [] []

    where
    get_aux t accu pos neg =
      case t of
        (Leaf True) -> (pos, neg):accu
        (Leaf False) -> accu
        (Split x p n) ->
          let accu' = get_aux p accu (x:pos) neg
          in
          get_aux n accu' pos (x:neg)

-- | Disjunctive normal form
-- Alternative representation for boolean formulas, sometime easier to use
--
-- The outer list corresponds to a bid disjunction, and for each element of
-- this list, the first element of the pair is a conjunction of atoms and the
-- second a conjonction of negated atoms.
type DNF a = [([a],[a])]

toDNF :: T a -> DNF a
toDNF = aux [] [] []
  where
    aux :: DNF a -> [a] -> [a] -> T a -> DNF a
    aux accu pos neg = \case
      Leaf True -> (pos, neg) : accu
      Leaf False -> accu
      Split { tif, tthen, telse } ->
        let accuR = aux accu (tif : pos) neg tthen
            accuRL = aux accuR pos (tif : neg) telse
        in
        accuRL
