module NixLight.Annotations.Parser
  ( typ
  , typeAnnot
  ) where

import           Control.Applicative (empty, (<|>))
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import           Nix.Expr (SrcSpan(..))
import qualified NixLight.Ast as Ast
import qualified NixLight.WithLoc as WL
import           Text.Parser.Combinators (eof, optional, sepBy1, try)
import           Text.Parser.Expression as PExpr
import qualified Text.Parser.Token as Tok
import qualified Text.Parser.Token.Style as TStyle
import           Text.Trifecta ((<?>))
import qualified Text.Trifecta as Tf
import           Text.Trifecta.Delta (Delta)

-- Stolen form hnix as it is unexported there
annotateLocation :: Tf.Parser a -> Tf.Parser (WL.T a)
annotateLocation p = do
  begin <- Tf.position
  res   <- p
  end   <- Tf.position
  let srcspan = SrcSpan begin end
  pure $ WL.T srcspan res

annotateLocation3 :: Tf.Parser (a -> b -> c) -> Tf.Parser (a -> b -> WL.T c)
annotateLocation3 p = do
  begin <- Tf.position
  res   <- p
  end   <- Tf.position
  let srcspan = SrcSpan begin end
  pure $ \x y -> WL.T srcspan (res x y)

ident :: Tf.Parser T.Text
ident = Tok.ident TStyle.emptyIdents

baseType :: Tf.Parser Ast.AnnotLoc
baseType = do
  Tok.whiteSpace
  annotateLocation $ Ast.Aident <$> ident

constant :: Tf.Parser Ast.AnnotLoc
constant = do
  Tok.whiteSpace
  annotateLocation $ Ast.Aconstant <$> (intConstant <|> boolConstant)
  where
    intConstant, boolConstant :: Tf.Parser Ast.Constant
    intConstant = Ast.Cint <$> Tok.integer
    boolConstant = Ast.Cbool <$> boolTok
    boolTok :: Tf.Parser Bool
    boolTok = do
      curIdent <- Tok.ident TStyle.emptyIdents
      case curIdent of
        "true" -> pure True
        "false" -> pure False
        _ -> empty

typeExpr :: Tf.Parser Ast.AnnotLoc
typeExpr = PExpr.buildExpressionParser ops atom
      <?> "type expression"

typ :: Tf.Parser Ast.AnnotLoc
typ = (annotateLocation $ do
  subT <- typeExpr
  bindsM <- optional $ do
    _ <- Tok.symbol "where"
    bindings <?> "type bindings"
  pure $ case bindsM of
    Just binds -> Ast.Awhere binds subT
    Nothing -> WL.descr subT)
  <?> "Type"

bindings :: Tf.Parser Ast.Abindings
bindings = Map.fromList <$> (flip sepBy1 (Tok.symbol "and") $ do
  lhs <- Tok.ident TStyle.emptyIdents
  _ <- Tok.symbol "="
  rhs <- typ
  pure (lhs, rhs))

ops :: PExpr.OperatorTable Tf.Parser Ast.AnnotLoc
ops = [
    [ binary "->" (annotateLocation3 $ pure Ast.Aarrow) AssocRight ],
    [ binary "&" (annotateLocation3 $ pure Ast.Aand) AssocRight ],
    [ binary "|" (annotateLocation3 $ pure Ast.Aor) AssocRight ],
    [ binary "\\" (annotateLocation3 $ pure Ast.Adiff) AssocRight ]
  ]
  where
    binary :: String -> Tf.Parser (Ast.AnnotLoc -> Ast.AnnotLoc -> Ast.AnnotLoc) -> Assoc -> Operator Tf.Parser Ast.AnnotLoc
    binary  name fun = Infix (fun <* Tok.symbol name)
    -- prefix  name fun = Prefix (fun <* Tok.symbol name)
    -- postfix name fun = Postfix (fun <* Tok.symbol name)

atom :: Tf.Parser Ast.AnnotLoc
atom = Tok.parens typ <|> try constant <|> baseType <?> "simple type"

typeAnnot :: Delta -> T.Text -> Tf.Result Ast.AnnotLoc
typeAnnot delta = Tf.parseString (Tf.spaces *> typ <* eof) delta . T.unpack
