-- | A simplified version of Nix Ast
module NixLight.Ast where

import           Data.Map.Strict (Map)
import           Data.Text (Text)
import qualified NixLight.WithLoc as WL
import qualified Types

data NoLocExpr
  = Econstant !Constant
  | Evar !Text
  | Eabs !Pattern !ExprLoc
  | Eapp !ExprLoc !ExprLoc
  | Eannot !Types.T !ExprLoc
  | EBinding !Bindings !ExprLoc
  | EIfThenElse { eif, ethen, eelse :: !ExprLoc }
  deriving (Ord, Eq)

type ExprLoc = WL.T NoLocExpr

data Constant
  = Cint Integer
  | Cbool Bool
  -- TODO: complete
  deriving (Ord, Eq)

data Pattern
  = Pvar !Text
  | Pannot !Types.T !Pattern
  deriving (Ord, Eq)

type Bindings = Map Text BindingDef

-- | Nix's binding can be of three forms (we currently only consider the case
-- where the lhs is a variable and not a more complex attribute path):
-- 1. x = e; (to which we add an optional type annotation)
-- 2. inherit x1 … xn;
-- 3. inherit (e) x1 _ xn;
--
-- The first one is kept as it is, the second one is translated to n binding of
-- the form @inherit xi@ (or mor exactly @xi = inherit@ and the third one is
-- translated to n binding of the form @xi = r.xi@.
data BindingDef
  = NamedVar {
      annot :: Maybe Types.T,
      rhs :: ExprLoc
    }
  | Inherit
  deriving (Ord, Eq)

data Annot
  = Aident !Text
  | Aarrow !AnnotLoc !AnnotLoc
  | Aor !AnnotLoc !AnnotLoc
  | Aand !AnnotLoc !AnnotLoc
  | Adiff !AnnotLoc !AnnotLoc
  | Aconstant !Constant
  | Awhere !Abindings !AnnotLoc
  deriving (Ord, Eq)

type AnnotLoc = WL.T Annot

type Abindings = Map Text AnnotLoc
