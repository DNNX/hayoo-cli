{-# LANGUAGE OverloadedStrings #-}

module Main where

import Paths_hayoo_cli (version)
import Data.Version (showVersion)
import Data.ByteString.Char8 (pack)
import qualified Data.ByteString.Lazy as BSL
import Data.Aeson
import Network.HTTP.Conduit
import Network.HTTP.Types.Header (hUserAgent, hAccept)
import Network.URL (encString, ok_url)
import Text.Pandoc (def, readHtml, writeAsciiDoc)
import Text.Pandoc.Options (WriterOptions(..))
import CliOptions
import HayooTypes

jsonData :: Opts -> IO BSL.ByteString
jsonData (Opts _ searchQuery) = do
    req <- parseUrl url
    let req' = req { requestHeaders = [acceptJSONHeader, userAgentHeader] }
    response <- withManager $ httpLbs req'
    return $ responseBody response
    where url              = "http://hayoo.fh-wedel.de/json?query=" ++ encQuery
          encQuery         = encString True ok_url searchQuery
          userAgent        = pack $ "hayoo-cli/" ++ showVersion version
          userAgentHeader  = (hUserAgent, userAgent)
          acceptJSONHeader = (hAccept, "application/json")

decodeHayooResponse :: BSL.ByteString -> HayooResponse
decodeHayooResponse bs = case eitherDecode bs of
    (Right res) -> res
    (Left err)  -> error $ show err

printDelimiter :: Char -> IO ()
printDelimiter = putStrLn . replicate 100

htmlToAscii :: String -> String
htmlToAscii = (writeAsciiDoc def {writerReferenceLinks = True}) . readHtml def

printResultFull :: HayooResult -> IO ()
printResultFull singleResult@(HayooResult { resultDescription = desc }) =
    printResultShort singleResult
    >> putStrLn ""
    >> (putStrLn $ htmlToAscii desc)

printResultShort :: HayooResult -> IO ()
printResultShort (HayooResult { resultName      = name
                              , resultSignature = signature
                              , resultModules   = modules
                              }) =
    putStrLn $ unwords $ modules ++ nameAndSignaruter name signature
    where nameAndSignaruter n "" = [n]
          nameAndSignaruter n s  = [n, "::", s]

printResponse :: Opts -> HayooResponse -> IO ()
printResponse _                           (HayooResponse { result = [] })      = putStrLn "No results found"
printResponse (Opts { showInfo = True })  (HayooResponse { result = (res:_) }) = printResultFull res
printResponse (Opts { showInfo = False }) (HayooResponse { result = results }) = mapM_ printResultShort results

run :: Opts -> IO ()
run opts =
    (jsonData opts)
    >>= ((printResponse opts) . decodeHayooResponse)

main :: IO ()
main = parseArguments ver run
       where ver = showVersion version
