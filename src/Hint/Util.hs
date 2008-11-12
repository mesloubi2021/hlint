{-# LANGUAGE PatternGuards #-}

module Hint.Util where

import Data.Generics
import Data.Generics.PlateData
import Data.List
import Data.Maybe
import Language.Haskell.Exts


declName :: HsDecl -> String
declName (HsPatBind _ (HsPVar (HsIdent name)) _ _) = name
declName (HsFunBind (HsMatch _ (HsIdent name) _ _ _ : _)) = name
declName x = error $ "declName: " ++ show x


parseHsModule :: FilePath -> IO HsModule
parseHsModule file = do
    res <- parseFile file
    case res of
        ParseOk x -> return x
        ParseFailed src msg -> do
            putStrLn $ "" ++ showSrcLoc src ++ ": Parse failure, " ++ msg
            return $ HsModule nullSrcLoc (Module "") Nothing [] []


---------------------------------------------------------------------
-- SRCLOC FUNCTIONS

nullSrcLoc :: SrcLoc
nullSrcLoc = SrcLoc "" 0 0

showSrcLoc :: SrcLoc -> String
showSrcLoc (SrcLoc file line col) = file ++ ":" ++ show line ++ ":" ++ show col ++ ":"

getSrcLoc :: Data a => a -> Maybe SrcLoc
getSrcLoc x = head $ gmapQ cast x ++ [Nothing]


---------------------------------------------------------------------
-- UNIPLATE STYLE FUNCTIONS

-- children on Exp, but with SrcLoc's
children1Exp :: Data a => SrcLoc -> a -> [(SrcLoc, HsExp)]
children1Exp src x = concat $ gmapQ (children0Exp src2) x
    where src2 = fromMaybe src (getSrcLoc x)

children0Exp :: Data a => SrcLoc -> a -> [(SrcLoc, HsExp)]
children0Exp src x | Just y <- cast x = [(src, y)]
                   | otherwise = children1Exp src x

universeExp :: Data a => SrcLoc -> a -> [(SrcLoc, HsExp)]
universeExp src x = concatMap f (children0Exp src x)
    where f (src,x) = (src,x) : concatMap f (children1Exp src x)


---------------------------------------------------------------------
-- VARIABLE MANIPULATION

-- pick a variable that is not being used
freeVar :: Data a => a -> String
freeVar x = head $ allVars \\ concat [[y, drop 1 y] | HsIdent y <- universeBi x]
    where allVars = [letter : number | number <- "" : map show [1..], letter <- ['a'..'z']]


fromVar :: HsExp -> Maybe String
fromVar (HsVar (UnQual (HsIdent x))) = Just x
fromVar _ = Nothing

toVar :: String -> HsExp
toVar = HsVar . UnQual . HsIdent

isVar :: HsExp -> Bool
isVar = isJust . fromVar
