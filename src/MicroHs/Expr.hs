module MicroHs.Expr(
  Ident, mkIdent, mkIdentLoc, unIdent, eqIdent, qual, showIdent,
  SLoc(..),
  Line, Col, Loc,
  IdentModule,
  EModule(..),
  ExportSpec(..),
  ImportSpec(..),
  EDef(..), showEDefs,
  Expr(..), showExpr,
  Lit(..), showLit,
  EBind(..),
  Eqn(..),
  EStmt(..),
  EAlts(..),
  EAlt,
  ECaseArm,
  EType,
  EPat, patVars, isPVar, isPConApp,
  EKind,
  LHS,
  Constr,
  ConTyInfo,
  ETypeScheme(..),
  Con(..), conIdent, conArity, eqCon,
  tupleConstr, untupleConstr,
  subst,
  allVarsExpr, allVarsBind
  ) where
import Prelude --Xhiding (Monad(..), Applicative(..), MonadFail(..), Functor(..), (<$>), showString, showChar, showList)
import Data.Char
import Data.List
import Data.Maybe
--Ximport Compat
--Ximport GHC.Stack

type Line = Int
type Col  = Int
type Loc  = (Line, Col)
--type SLoc = (FilePath, Loc)

data SLoc = SLoc FilePath Line Col
  --Xderiving (Show, Eq)

noSLoc :: SLoc
noSLoc = SLoc "" 0 0

--noLoc :: Loc
--noLoc = (0,0)

data Ident = Ident SLoc String
  --Xderiving (Show, Eq)
type IdentModule = Ident

mkIdent :: String -> Ident
mkIdent = Ident noSLoc

mkIdentLoc :: FilePath -> Loc -> String -> Ident
mkIdentLoc fn (l, c) s = Ident (SLoc fn l c) s

unIdent :: Ident -> String
unIdent (Ident _ s) = s

eqIdent :: Ident -> Ident -> Bool
eqIdent (Ident _ i) (Ident _ j) = eqString i j

----------------------

data EModule = EModule IdentModule [ExportSpec] [EDef]
  --Xderiving (Show, Eq)

data ExportSpec
  = ExpModule IdentModule
  | ExpTypeCon Ident
  | ExpType Ident
  | ExpValue Ident
  --Xderiving (Show, Eq)

qual :: Ident -> Ident -> Ident
qual (Ident loc qi) (Ident _ i) = Ident loc (qi ++ "." ++ i)

isConIdent :: Ident -> Bool
isConIdent (Ident _ i) =
  let
    c = head i
  in isUpper c || eqChar c ':' || eqChar c ',' || eqString i "[]"  || eqString i "()"

data EDef
  = Data LHS [Constr]
  | Newtype LHS Ident EType
  | Type LHS EType
  | Fcn Ident [Eqn]
  | Sign Ident ETypeScheme
  | Import ImportSpec
  --Xderiving (Show, Eq)

data ImportSpec = ImportSpec Bool Ident (Maybe Ident)
  --Xderiving (Show, Eq)

data Expr
  = EVar Ident
  | EApp Expr Expr
  | ELam [EPat] Expr
  | ELit Lit
  | ECase Expr [ECaseArm]
  | ELet [EBind] Expr
  | ETuple [Expr]
  | EList [Expr]
  | EDo (Maybe Ident) [EStmt]
  | ESectL Expr Ident
  | ESectR Ident Expr
  | EIf Expr Expr Expr
  | ECompr Expr [EStmt]
  | EAt Ident Expr  -- only in patterns
  -- Only while type checking
  | EUVar Int
  -- Constructors after type checking
  | ECon Con
  --Xderiving (Show, Eq)

data Con
  = ConData ConTyInfo Ident
  | ConNew Ident
  | ConLit Lit
--  | ConTup Int
  --Xderiving(Show, Eq)

conIdent :: --XHasCallStack =>
            Con -> Ident
conIdent (ConData _ i) = i
conIdent (ConNew i) = i
conIdent _ = undefined

conArity :: Con -> Int
conArity (ConData cs i) = fromMaybe undefined $ lookupBy eqIdent i cs
conArity (ConNew _) = 1
conArity (ConLit _) = 0
--conArity (ConTup n) = n

eqCon :: Con -> Con -> Bool
eqCon (ConData _ i) (ConData _ j) = eqIdent i j
eqCon (ConNew    i) (ConNew    j) = eqIdent i j
eqCon (ConLit    l) (ConLit    k) = eqLit   l k
eqCon _             _             = False

data Lit = LInt Int | LChar Char | LStr String | LPrim String
  --Xderiving (Show, Eq)

eqLit :: Lit -> Lit -> Bool
eqLit (LInt x)  (LInt  y) = x == y
eqLit (LChar x) (LChar y) = eqChar x y
eqLit (LStr  x) (LStr  y) = eqString x y
eqLit (LPrim x) (LPrim y) = eqString x y
eqLit _         _         = False

type ECaseArm = (EPat, EAlts)

data EStmt = SBind EPat Expr | SThen Expr | SLet [EBind]
  --Xderiving (Show, Eq)

data EBind = BFcn Ident [Eqn] | BPat EPat Expr
  --Xderiving (Show, Eq)

-- A single equation for a function
data Eqn = Eqn [EPat] EAlts
  --Xderiving (Show, Eq)

data EAlts = EAlts [EAlt] [EBind]
  --Xderiving (Show, Eq)

type EAlt = ([EStmt], Expr)

type ConTyInfo = [(Ident, Int)]    -- All constructors with their arities

{-
data EPat
  = PConstr ConTyInfo Ident [EPat]
  | PVar Ident
  --Xderiving (Show, Eq)
-}
type EPat = Expr

isPVar :: EPat -> Bool
isPVar (EVar i) = not (isConIdent i)
isPVar _ = False    

isPConApp :: EPat -> Bool
isPConApp (EVar i) = isConIdent i
isPConApp (EApp f _) = isPConApp f
isPConApp _ = True

patVars :: EPat -> [Ident]
patVars = filter (not . isConIdent) . allVarsExpr

type LHS = (Ident, [Ident])
type Constr = (Ident, [EType])

-- Expr restricted to
--  * after desugaring: EApp and EVar
--  * before desugaring: EApp, EVar, ETuple, EList
type EType = Expr

{-
validType :: Expr -> Bool
validType ae =
  case ae of
    EVar _ -> True
    EApp f a -> validType f && validType a
    EList es -> length es <= 1 && all validType (take 1 es)
    ETuple es -> all validType es
    _ -> False
-}

data ETypeScheme = ETypeScheme [Ident] EType
  --Xderiving (Show, Eq)

type EKind = EType

{-
leIdent :: Ident -> Ident -> Bool
leIdent = leString
-}

tupleConstr :: Int -> Ident
tupleConstr n = mkIdent (replicate (n - 1) ',')

untupleConstr :: Ident -> Int
untupleConstr i = length (unIdent i) + 1

---------------------------------

-- Enough to handle subsitution in types
subst :: [(Ident, Expr)] -> Expr -> Expr
subst s =
  let
    sub ae =
      case ae of
        EVar i -> fromMaybe ae $ lookupBy eqIdent i s
        EApp f a -> EApp (sub f) (sub a)
        EUVar _ -> ae
        _ -> error "subst unimplemented"
  in sub

allVarsBind :: EBind -> [Ident]
allVarsBind abind =
  case abind of
    BFcn i eqns -> i : concatMap allVarsEqn eqns
    BPat p e -> allVarsPat p ++ allVarsExpr e

allVarsEqn :: Eqn -> [Ident]
allVarsEqn eqn =
  case eqn of
    Eqn ps alts -> concatMap allVarsPat ps ++ allVarsAlts alts

allVarsAlts :: EAlts -> [Ident]
allVarsAlts (EAlts alts bs) = concatMap allVarsAlt alts ++ concatMap allVarsBind bs

allVarsAlt :: EAlt -> [Ident]
allVarsAlt (ss, e) = concatMap allVarsStmt ss ++ allVarsExpr e

allVarsPat :: EPat -> [Ident]
allVarsPat = allVarsExpr

allVarsExpr :: Expr -> [Ident]
allVarsExpr aexpr =
  case aexpr of
    EVar i -> [i]
    EApp e1 e2 -> allVarsExpr e1 ++ allVarsExpr e2
    ELam ps e -> concatMap allVarsPat ps ++ allVarsExpr e
    ELit _ -> []
    ECase e as -> allVarsExpr e ++ concatMap allVarsCaseArm as
    ELet bs e -> concatMap allVarsBind bs ++ allVarsExpr e
    ETuple es -> concatMap allVarsExpr es
    EList es -> concatMap allVarsExpr es
    EDo mi ss -> maybe [] (:[]) mi ++ concatMap allVarsStmt ss
    ESectL e i -> i : allVarsExpr e
    ESectR i e -> i : allVarsExpr e
    EIf e1 e2 e3 -> allVarsExpr e1 ++ allVarsExpr e2 ++ allVarsExpr e3
    ECompr e ss -> allVarsExpr e ++ concatMap allVarsStmt ss
    EAt i e -> i : allVarsExpr e
    EUVar _ -> []
    ECon c -> [conIdent c]

allVarsCaseArm :: ECaseArm -> [Ident]
allVarsCaseArm (p, alts) = allVarsPat p ++ allVarsAlts alts

allVarsStmt :: EStmt -> [Ident]
allVarsStmt astmt =
  case astmt of
    SBind p e -> allVarsPat p ++ allVarsExpr e
    SThen e -> allVarsExpr e
    SLet bs -> concatMap allVarsBind bs

----------------

{-
showEModule :: EModule -> String
showEModule am =
  case am of
    EModule i es ds -> "module " ++ i ++ "(\n" ++
      unlines (intersperse "," (map showExportSpec es)) ++
      "\n) where\n" ++
      showEDefs ds

showExportSpec :: ExportSpec -> String
showExportSpec ae =
  case ae of
    ExpModule i -> "module " ++ i
    ExpTypeCon i -> i ++ "(..)"
    ExpType i -> i
    ExpValue i -> i
-}

showIdent :: Ident -> String
showIdent (Ident _ i) = i

showEDef :: EDef -> String
showEDef def =
  case def of
    Data lhs _ -> "data " ++ showLHS lhs ++ " = ..."
    Newtype lhs c t -> "newtype " ++ showLHS lhs ++ " = " ++ showIdent c ++ " " ++ showEType t
    Type lhs t -> "type " ++ showLHS lhs ++ " = " ++ showEType t
    Fcn i eqns -> unlines (map (\ (Eqn ps alts) -> showIdent i ++ " " ++ unwords (map showEPat ps) ++ showAlts "=" alts) eqns)
    Sign i t -> showIdent i ++ " :: " ++ showETypeScheme t
    Import (ImportSpec q m mm) -> "import " ++ (if q then "qualified " else "") ++ showIdent m ++ maybe "" ((" as " ++) . unIdent) mm

showLHS :: LHS -> String
showLHS lhs =
  case lhs of
    (f, vs) -> unwords (map unIdent (f : vs))

showEDefs :: [EDef] -> String
showEDefs ds = unlines (map showEDef ds)

showAlts :: String -> EAlts -> String
showAlts sep (EAlts alts bs) = showAltsL sep alts ++ showWhere bs

showWhere :: [EBind] -> String
showWhere [] = ""
showWhere bs = "where\n" ++ unlines (map showEBind bs)

showAltsL :: String -> [EAlt] -> String
showAltsL sep [([], e)] = " " ++ sep ++ " " ++ showExpr e
showAltsL sep alts = unlines (map (showAlt sep) alts)

showAlt :: String -> EAlt -> String
showAlt sep (ss, e) = " | " ++ concat (intersperse ", " (map showEStmt ss)) ++ " " ++ sep ++ " " ++ showExpr e

showExpr :: Expr -> String
showExpr ae =
  case ae of
--X    EVar (Ident _ "Primitives.Char") -> "Char"
--X    EVar (Ident _ "Primitives.->") -> "(->)"
--X    EApp (EApp (EVar (Ident _ "Primitives.->")) a) b -> "(" ++ showExpr a ++ " -> " ++ showExpr b ++ ")"
--X    EApp (EVar (Ident _ "Data.List.[]")) a -> "[" ++ showExpr a ++ "]"
--X    EApp (EApp (EVar (Ident _ ",")) a) b -> showExpr (ETuple [a,b])
    EVar v -> showIdent v
    EApp f a -> "(" ++ showExpr f ++ " " ++ showExpr a ++ ")"
    ELam ps e -> "(\\" ++ unwords (map showExpr ps) ++ " -> " ++ showExpr e ++ ")"
    ELit i -> showLit i
    ECase e as -> "case " ++ showExpr e ++ " of {\n" ++ unlines (map showCaseArm as) ++ "}"
    ELet bs e -> "let\n" ++ unlines (map showEBind bs) ++ "in " ++ showExpr e
    ETuple es -> "(" ++ intercalate "," (map showExpr es) ++ ")"
    EList es -> showList showExpr es
    EDo mn ss -> maybe "do" (\ n -> showIdent n ++ ".do\n") mn ++ unlines (map showEStmt ss)
    ESectL e i -> "(" ++ showExpr e ++ " " ++ showIdent i ++ ")"
    ESectR i e -> "(" ++ showIdent i ++ " " ++ showExpr e ++ ")"
    EIf e1 e2 e3 -> "if " ++ showExpr e1 ++ " then " ++ showExpr e2 ++ " else " ++ showExpr e3
    ECompr _ _ -> "ECompr"
    EAt i e -> showIdent i ++ "@" ++ showExpr e
    EUVar i -> "a" ++ showInt i
    ECon c -> showCon c

showCon :: Con -> String
showCon (ConData _ s) = showIdent s
showCon (ConNew s) = showIdent s
showCon (ConLit l) = showLit l
--showCon (ConTup n) = "(" ++ tupleConstr n ++ ")"

showLit :: Lit -> String
showLit l =
  case l of
    LInt i -> showInt i
    LChar c -> showChar c
    LStr s -> showString s
    LPrim s -> '$':s

showEStmt :: EStmt -> String
showEStmt as =
  case as of
    SBind p e -> showEPat p ++ " <- " ++ showExpr e
    SThen e -> showExpr e
    SLet bs -> "let\n" ++ unlines (map showEBind bs)

showEBind :: EBind -> String
showEBind ab =
  case ab of
    BFcn i eqns -> showEDef (Fcn i eqns)
    BPat p e -> showEPat p ++ " = " ++ showExpr e

showCaseArm :: ECaseArm -> String
showCaseArm arm =
  case arm of
    (p, alts) -> showEPat p ++ showAlts "->" alts

showEPat :: EPat -> String
showEPat = showExpr

showEType :: EType -> String
showEType = showExpr

showETypeScheme :: ETypeScheme -> String
showETypeScheme ts =
  case ts of
    ETypeScheme vs t ->
      if null vs
      then showEType t
      else unwords ("forall" : map unIdent vs ++ [".", showEType t])

