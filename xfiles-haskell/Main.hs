module Main where

import Control.Monad
import Data.List
import System.Directory
import System.Environment
import System.Posix.IO
import System.Posix.Terminal
import System.Posix.User
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO

splitPath :: String -> [String]
splitPath path = foldr qual [""] path where
    qual '/' a = [""] ++ a
    qual c (p:r) = ([c]++p):r

normalizeParts :: [String] -> [String]
normalizeParts (p1:parts) = reverse $ foldr norm [p1] (reverse parts) where
    norm "" a = a
    norm "." a = a
    norm ".." [""] = [""]
    norm ".." (h:r) = r
    norm p a = [p] ++ a

getUserHomeParts :: String -> IO [String]
getUserHomeParts user = do
    userEntry <- getUserEntryForName user
    let home_parts = splitPath $ homeDirectory userEntry
    return home_parts

prepend :: [String] -> IO ([String])
prepend ("~":parts) = do
    user <- getLoginName
    home_parts <- getUserHomeParts user
    return $ home_parts ++ parts
prepend (('~':user):parts) = do
    home_parts <- getUserHomeParts user
    return $ home_parts ++ parts
prepend ("":parts) = return ("":parts)
prepend parts = do
    cwd <- getCurrentDirectory
    let cwd_parts = splitPath cwd
    return $ cwd_parts ++ parts

normalizePath :: String -> IO (String)
normalizePath path = do
    abs_parts <- prepend $ splitPath path
    let norm_path = "/" `intercalate` normalizeParts abs_parts
    return $ if norm_path == "" then "/" else norm_path

getStdinArgs :: IO([String])
getStdinArgs = do
    stdinText <- getContents
    stdinIsAtty <- queryTerminal stdInput
    return $ if stdinIsAtty then [] else lines stdinText

data Selection = Selection {path :: String} deriving (Show)

newSelection :: IO (Selection)
newSelection = do
    let shm = "/dev/shm"
    shmExists <- doesDirectoryExist shm
    let path = (if shmExists then shm else "/tmp") ++ "/xfiles"
    let selection = Selection path
    return selection

showPath :: Selection -> IO ()
showPath selection = do
    putStrLn $ path selection

showItems :: Selection -> IO ()
showItems selection = do
    text <- readFile $ path selection
    let textn = if text=="" then text else text ++ "\n"
    putStr textn

clearItems :: Selection -> IO ()
clearItems selection = do
    writeFile (path selection) ""

addItems :: Selection -> [String] -> IO ()
addItems selection items = do
    -- We need Text, not String, because String would lead to leazy reading
    -- of the file, so that we couldn't write at the same time.
    old_text <- TextIO.readFile $ path selection
    let old_items = lines $ Text.unpack old_text
    abs_items <- mapM normalizePath (old_items ++ items)
    let all_items = nub $ filter (/= "") abs_items
    let text = intercalate "\n" all_items
    writeFile (path selection) text

removeItems :: Selection -> [String] -> IO ()
removeItems selection items = do
    -- We need Text, not String, because String would lead to leazy reading
    -- of the file, so that we couldn't write at the same time.
    old_text <- TextIO.readFile $ path selection
    let old_items = lines $ Text.unpack old_text
    norm_items <- mapM normalizePath items
    let abs_items = filter (/= "") norm_items
    let all_items = old_items \\ abs_items
    let text = intercalate "\n" all_items
    writeFile (path selection) text

getCmdArgs :: [String] -> IO [String]
getCmdArgs cliArgs = do
    stdinArgs <- getStdinArgs
    return $ if null cliArgs then stdinArgs else cliArgs

parseArgs :: Selection -> [String] -> IO ()
parseArgs selection ("+":cliArgs) = do
    cmdArgs <- getCmdArgs cliArgs
    addItems selection cmdArgs
    showItems selection
parseArgs selection ("-":cliArgs) = do
    cmdArgs <- getCmdArgs cliArgs
    removeItems selection cmdArgs
    showItems selection
parseArgs selection ("++":cliArgs) = showPath selection
parseArgs selection ("--":cliArgs) = clearItems selection
parseArgs selection [] = do
    stdinArgs <- getStdinArgs
    when (not $ null stdinArgs) $ do
        clearItems selection
        addItems selection stdinArgs
    showItems selection
parseArgs selection cliArgs = do
    cmdArgs <- getCmdArgs cliArgs
    clearItems selection
    addItems selection cmdArgs
    showItems selection

main :: IO ()
main = do
    selection <- newSelection
    args <- getArgs
    parseArgs selection args
