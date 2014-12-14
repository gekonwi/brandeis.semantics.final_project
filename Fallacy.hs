import Control.Monad  
import qualified Data.Map as M
import qualified Data.List.Split as Split
import Data.Logic.Propositional
import qualified Data.Text as T
import qualified Data.Char as Char 
import qualified NLP.POS as POS
import qualified NLP.Types.Tree as Types
import NLP.Corpora.Conll (Tag)
import NLP.Stemmer


type Subj = String
type Pred = String
type Obj = String

data UnaryOp = Not | None deriving (Show)

data TripleTree = Triple Subj Pred Obj
          | Neg TripleTree
          | Conj TripleTree TripleTree
          | Disj TripleTree TripleTree
          | Cond TripleTree TripleTree
          deriving (Eq, Show)

puncList, conclusionWordList, stopWords :: [String]
puncList = [",", ".", ";", ":"]
conclusionWordList = ["therefore", "so", "hence"]
stopWords = ["do", "does", "a", "an", "the", "of", "to"]

var = Variable . Var
neg = Negation
conj = Conjunction
disj = Disjunction
cond = Conditional
iff = Biconditional

main = forever $ do  
               putStr "> "  
               l <- getLine
               res <- parseSent l
               putStrLn $ "Is fallacy? " ++ show(res)
{- tagString
- parses the input string, and handles POS tagging
-
- parameters:
-   String: the string that we are trying to detect containing fallacies
-   (if any)
-}

tagString :: String -> IO [Types.TaggedSentence NLP.Corpora.Conll.Tag]
tagString input = do 
               tagger <- POS.defaultTagger
               return (POS.tag tagger (T.pack input))

tagStringTuple :: String -> IO [[(String, String)]]
tagStringTuple input = do
        taggedSents <- tagString input
        let posList = [Types.unTS x | x <- taggedSents] 
            tags = map (\s -> 
                       foldl (\acc p -> 
                             let tok = T.unpack $ Types.showPOStok p
                                 pos = T.unpack $ Types.showPOStag p
                                 in acc ++ [(toLower tok, pos)]) [] s
                        ) posList
            in return (tags)

toLower :: String -> String
toLower word = map (\c -> Char.toLower c) word

setSentBoundaries :: String -> String
setSentBoundaries sentence = unwords $ map (\w -> case w of 
                             "and" -> "."
                             "," -> "."
                             _ -> w) $ words sentence


stemString :: String -> String
stemString input = 
        let filtered = filter (\s -> (toLower s) `notElem` stopWords) $ words input 
            in unwords $ map (stem English) $ filtered


removePunc :: [(String, b)] -> [(String, b)]
removePunc = foldr (\tuple acc -> if (fst tuple) `elem` puncList then acc else tuple:acc) []

removeConclusionWords :: [(String, b)] -> [(String, b)]
removeConclusionWords = foldr (\tuple acc -> if (fst tuple) `elem` conclusionWordList then acc else tuple:acc) []

extractPremiseConclusion :: [([Char], b)] -> ([([Char], b)], [([Char], b)])
extractPremiseConclusion = span (\e -> (fst e) `notElem` conclusionWordList) 

extractPremiseConclusionAll :: String -> IO ([[(String, String)]], [[(String, String)]])
extractPremiseConclusionAll sentence = do 
                  tagged <- tagStringTuple (setSentBoundaries $ stemString sentence)
                  let t = map (\s -> 
                              let (p, q) = extractPremiseConclusion s 
                                  in (removePunc p, removeConclusionWords $ removePunc q)

                              {-(notList, sentWords) = foldr (\w acc -> -}
                                {-if fst w == "not" then ("not":fst acc, snd acc) else (fst acc, fst w:snd acc)) ([], []) s-}

                              {-sent = unwords $ foldr (\w acc -> if length w > 0 then w:acc else acc) [] sentWords-}
                              {-notVal = if even $ length notList then None else Not-}
                              {-in (notVal, sent)-}
                              {-in (premise, conclusion)-}
                              ) tagged 
                      (premise, conclusion) = foldr (\(p, q) acc -> if length p > 0 then (p:fst acc, snd acc) else (fst acc, q:snd acc)) ([], []) t
                        in return (premise, conclusion)

toString :: [[(String, b)]] -> [String]
toString sentList = foldr (\l acc -> unwords [fst x | x <- l]:acc) [] sentList

removeWord :: String -> String -> String
removeWord word sent = unwords $ foldr (\w acc -> if w == word then acc else w:acc) [] (words sent)

replaceKeywords :: ([[(String, b)]], [[(String, b1)]]) -> ([Expr], [Expr])
replaceKeywords (premise, conclusion) = 
        let (psent, qsent) = (toString premise, toString conclusion)
            lst = psent ++ qsent
            varMap = foldr (\s acc -> 
                           let sent = removeWord "not" s
                               in if M.member sent acc then acc 
                                             else M.insert sent (Char.chr(M.size acc+96)) acc
                                             ) (M.fromList [("", '_')]) lst
            finalMap = M.delete "" varMap
            in (sentToFormula finalMap psent, sentToFormula finalMap qsent)

getVarName :: Maybe Char -> Char
getVarName (Just x) = x
getVarName _ = '_'

sentToFormula :: M.Map String Char -> [String] -> [Expr]
sentToFormula varMap sent = 
        foldr (\s acc -> 
              let sw = words s 
                  hasNot = if "not" `elem` sw then True else False
                  {-hasOr = if "or" `elem` sw then True else False-}
                  {-hasIf = if "if" `elem` sw && "then" `elem` sw then True else False-}
                  cleanedSent = if hasNot then removeWord "not" s else s
                  varName = getVarName $ M.lookup cleanedSent varMap
                  sentVar = if hasNot then neg $ var varName else var varName
                  in sentVar:acc) [] sent

reduceAnd :: [Expr] -> Expr
reduceAnd [] = error "Empty expression list is given"
reduceAnd [x] = x
reduceAnd (s:sx) = conj s (reduceAnd sx)

parseSent :: String -> IO String
parseSent sentence = do
        t <- extractPremiseConclusionAll sentence
        let (p, q) = replaceKeywords t
            result = if length p < 2 && length q < 2 
                         then "Not enough propositions given." 
                         else show $ isFallacy $ Conditional (reduceAnd p) (reduceAnd q)
            in return (result)


{-
========================================================================
affirmDisj
========================================================================

The pattern for 'Affirming a Disjunct' fallacy is
(a OR b) AND a => NOT b

parameters:	
	Var: variable to be mapped as a in the formula above
	Var: variable to be mapped as b in the formula above

returns:
	Expr: the expression `(a OR b) AND a => NOT b` with `a` and `b` being
		replaced by the two variables given as parameters	
-}

affirmDisj :: Var -> Var -> Expr
affirmDisj a b = affirmDisj_left `cond` affirmDisj_right
	where
		aExp = Variable a
		bExp = Variable b
		affirmDisj_left = (aExp `disj` bExp) `conj` aExp
		affirmDisj_right = (neg bExp)


{-
========================================================================
isFallacy
========================================================================

Checks if the given expression is a fallacy. All detectable fallacies have
	the form `expression1 => expression2`. If the given expression does not
	have this form, it is not a fallacy (although it might contain a 
	contradiction).

parameters:	
	Expr: the expression to be checked for contained fallacies

returns
	Bool: True if the given expression contains one of the fallacies we 
		detect here, otherwise False
-}
isFallacy :: Expr -> Bool
isFallacy (Conditional left right) = any isFallacyMapping varPairs
	where

		isFallacyMapping :: (Var, Var) -> Bool
		isFallacyMapping varPair = 
			isTautology (left `cond` fallacy_left) && 
			isTautology (right `cond` fallacy_right)

			where
				(Conditional fallacy_left fallacy_right) =
					affirmDisj (fst varPair) (snd varPair)

		varPairs = [(a, b) | a <- variables left, b <- variables left]

isFallacy _ = False
