module MicroHs.Lex(
  lexTop,
  Token(..), Line, Col,
  Loc, getCol, getLin,
  isLower_,
  tokensLoc) where
import Prelude --Xhiding(lex, showChar)
import Data.Char
--Ximport Compat
--import Debug.Trace
import MicroHs.Expr --X(Line, Col, Loc)

data Token
  = TIdent  Loc [String] String
  | TString Loc String
  | TChar   Loc Char
  | TInt    Loc Int
  | TSpec   Loc Char
  | TError  Loc String
  | TBrace  Loc
  | TIndent Loc
  --Xderiving (Show)

incrLine :: Loc -> Loc
incrLine (l, _) = (l+1, 1)

addCol :: Loc -> Int -> Loc
addCol (l, c) i = (l, c + i)

mkLoc :: Line -> Col -> Loc
mkLoc l c = (l, c)

getCol :: Loc -> Col
getCol (_, c) = c

getLin :: Loc -> Col
getLin (l, _) = l

{-  This is slower and allocates more.
    It needs some strictness, probably
type Loc = Int

incrLine :: Loc -> Loc
incrLine l = (quot l 1000000 + 1) * 1000000 + 1

addCol :: Loc -> Int -> Loc
addCol loc i = loc + i

mkLoc :: Line -> Col -> Loc
mkLoc l c = l * 1000000 + c

getCol :: Loc -> Col
getCol loc = rem loc 1000000

getLin :: Loc -> Line
getLin loc = quot loc 1000000
-}

---------

lexTop :: String -> [Token]
lexTop = layout [] .
         --take 10 .
         lex (mkLoc 1 1)

lex :: Loc -> String -> [Token]
lex loc (' ':cs)  = lex (addCol loc 1) cs
lex loc ('\n':cs) = tIndent (lex (incrLine loc) cs)
lex loc ('\r':cs) = lex loc cs
lex loc ('{':'-':cs) = skipNest (addCol loc 2) 1 cs
lex loc ('-':'-':cs) | isComm rs = skipLine (addCol loc $ 2+length ds) cs
  where {
    (ds, rs) = span (eqChar '-') cs;
    isComm [] = True;
    isComm (d:_) = not (isOper d)
    }
lex loc (d:cs) | isLower_ d =
  case span isIdent cs of
    (ds, rs) -> tIdent loc [] (d:ds) (lex (addCol loc $ 1 + length ds) rs)
lex loc cs@(d:_) | isUpper d = upperIdent loc loc [] cs
lex loc ('-':d:cs) | isDigit d =
  case span isDigit cs of
    (ds, rs) -> TInt loc (readInt ('-':d:ds)) : lex (addCol loc $ 2 + length ds) rs
lex loc (d:cs) | isDigit d =
  case span isDigit cs of
    (ds, rs) -> TInt loc (readInt (d:ds)) : lex (addCol loc $ 1 + length ds) rs
lex loc (d:cs) | isOper d  =
  case span isOper cs of
    (ds, rs) -> TIdent loc [] (d:ds) : lex (addCol loc $ 1 + length ds) rs
lex loc (d:cs) | isSpec d  = TSpec loc d : lex (addCol loc 1) cs
lex loc ('"':cs) =
  case takeChars loc (TString loc) '"' 0 [] cs of
    (t, n, rs) -> t : lex (addCol loc $ 2 + n) rs
lex loc ('\'':cs) =
  case takeChars loc (TChar loc . head) '\'' 0 [] cs of  -- XXX head of
    (t, n, rs) -> t : lex (addCol loc $ 2 + n) rs
lex loc (d:_) = [TError loc $ "Unrecognized input: " ++ showChar d]
lex _ [] = []

-- Skip a { - - } style comment
skipNest :: Loc -> Int -> String -> [Token]
skipNest loc 0 cs           = lex loc cs
skipNest loc n ('{':'-':cs) = skipNest (addCol loc 2) (n + 1) cs
skipNest loc n ('-':'}':cs) = skipNest (addCol loc 2) (n - 1) cs
skipNest loc n ('\n':cs)    = skipNest (incrLine loc)  n     cs
skipNest loc n ('\r':cs)    = skipNest loc             n     cs
skipNest loc n (_:cs)       = skipNest (addCol loc 1)  n     cs
skipNest loc _ []           = [TError loc "Unclosed {- comment"]

-- Skip a -- style comment
skipLine :: Loc -> String -> [Token]
skipLine loc cs@('\n':_) = lex loc cs
skipLine loc (_:cs)      = skipLine loc cs
skipLine   _ []          = []

tIndent :: [Token] -> [Token]
tIndent ts@(TIndent _ : _) = ts
tIndent ts = TIndent (tokensLoc ts) : ts

takeChars :: Loc -> (String -> Token) -> Char -> Int -> String -> String -> (Token, Int, String)
takeChars loc _ c n _ [] = (TError loc ("Unmatched " ++ [c]), n, [])
takeChars loc fn c n str ('\\':cs) =
  case decodeChar (n+1) cs of
    (d, m, rs) -> takeChars loc fn c m (d:str) rs
takeChars   _ fn c n str (d:cs) | eqChar c d = (fn (reverse str), n, cs)
takeChars loc fn c n str (d:cs) = takeChars loc fn c (n+1) (d:str) cs

decodeChar :: Int -> String -> (Char, Int, String)
decodeChar n ('n':cs) = ('\n', n+1, cs)
decodeChar n ('r':cs) = ('\r', n+1, cs)
decodeChar n ('t':cs) = ('\t', n+1, cs)
decodeChar n (c  :cs) = (c,    n+1, cs)
decodeChar n []       = ('X',  n,   [])

isOper :: Char -> Bool
isOper c = elemBy eqChar c "@\\=+-:<>.!#$%^&*/|~?"

isSpec :: Char -> Bool
isSpec c = elemBy eqChar c "()[],{}`;"

isIdent :: Char -> Bool
isIdent c = isLower_ c || isUpper c || isDigit c || eqChar c '\''

isLower_ :: Char -> Bool
isLower_ c = isLower c || eqChar c '_'

upperIdent :: Loc -> Loc -> [String] -> String -> [Token]
--upperIdent l c qs acs | trace (show (l, c, qs, acs)) False = undefined
upperIdent loc sloc qs acs =
  case span isIdent acs of
   (ds, rs) ->
    case rs of
      '.':cs@(d:_) | isUpper d -> upperIdent (addCol loc $ 1 + length ds) sloc (ds:qs) cs
                   | isLower d -> ident isIdent
                   | isOper  d -> ident isOper
         where {
           ident p =
             case span p cs of
               (xs, ys) -> tIdent sloc (reverse (ds:qs)) xs (lex (addCol loc $ 1 + length ds + length xs) ys)
           }
      _ -> TIdent sloc (reverse qs) ds : lex (addCol loc $ length ds) rs

tIdent :: Loc -> [String] -> String -> [Token] -> [Token]
tIdent loc qs kw ats | elemBy eqString kw ["let", "where", "do", "of"]
                                 = ti : tBrace ats
                     | otherwise = ti : ats
  where {
    ti = TIdent loc qs kw;

    tBrace ts@(TSpec _ '{' : _) = ts;
    tBrace ts@(TIndent _ : TSpec _ '{' : _) = ts;
    tBrace (TIndent _ : ts) = TBrace (tokensLoc ts) : ts;
    tBrace ts = TBrace (tokensLoc ts) : ts
    }

tokensLoc :: [Token] -> Loc
tokensLoc (TIdent  loc _ _:_) = loc
tokensLoc (TString loc _  :_) = loc
tokensLoc (TChar   loc _  :_) = loc
tokensLoc (TInt    loc _  :_) = loc
tokensLoc (TSpec   loc _  :_) = loc
tokensLoc (TError  loc _  :_) = loc
tokensLoc (TBrace  loc    :_) = loc
tokensLoc (TIndent loc    :_) = loc
tokensLoc []                  = mkLoc 0 1

layout :: [Int] -> [Token] -> [Token]
layout mms@(m : ms) tts@(TIndent x       : ts) | n == m = TSpec (tokensLoc ts) ';' : layout    mms  ts
                                               | n <  m = TSpec (tokensLoc ts) '}' : layout     ms tts where {n = getCol x}
layout          ms      (TIndent _       : ts)          =                            layout     ms  ts
layout mms@(m :  _)     (TBrace x        : ts) | n > m  = TSpec (tokensLoc ts) '{' : layout (n:mms) ts where {n = getCol x}
layout          []      (TBrace x        : ts) | n > 0  = TSpec (tokensLoc ts) '{' : layout     [n] ts where {n = getCol x}
layout     (0 : ms)     (t@(TSpec _ '}') : ts)          =                        t : layout     ms  ts 
layout           _      (  (TSpec l '}') :  _)          = TError l "layout error }": []
layout          ms      (t@(TSpec _ '{') : ts)          =                        t : layout  (0:ms) ts
layout          ms      (t               : ts)          =                        t : layout     ms  ts
layout     (_ : ms)     []                              = TSpec (mkLoc 0 0) '}'    : layout     ms  []
layout          []      []                              =                            []
--layout           _      _                             = TError (mkLoc 0 0) "layout error"  : []
