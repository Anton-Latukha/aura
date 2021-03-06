{-

Copyright 2012 - 2017 Colin Woodbury <colingw@gmail.com>

This file is part of Aura.

Aura is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Aura is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Aura.  If not, see <http://www.gnu.org/licenses/>.

-}

module Aura.Flags
    ( parseLanguageFlag
    , parseFlags
    , settingsFlags
    , reconvertFlags
    , dualFlagMap
    , hijackedFlagMap
    , pacmanFlagMap
    , confirmationStatus
    , customizepkgStatus
    , delMakeDepsStatus
    , hotEditStatus
    , keepSourceStatus
    , neededStatus
    , noPowerPillStatus
    , pbDiffStatus
    , quietStatus
    , rebuildDevelStatus
    , sortSchemeStatus
    , suppressionStatus
    , truncationStatus
    , dryRunStatus
    , notSettingsFlag
    , ignoredAuraPkgs
    , makepkgFlags
    , buildPath
    , buildUser
    , auraOperMsg
    , Flag(..) ) where

import System.Console.GetOpt
import Data.Monoid
import Data.Foldable
import Data.Maybe (fromMaybe)
import Text.Read (readMaybe)

import Aura.Colour.Text (yellow)
import Aura.Settings.Base
import Aura.Languages

import Utilities (notNull, split)

---

type FlagMap = Flag -> String

data Flag = ABSInstall
          | AURInstall
          | SaveState
          | Cache
          | LogFile
          | Orphans
          | Search
          | Info
          | Refresh
          | GetPkgbuild
          | ViewDeps
          | DelMDeps
          | Upgrade
          | Download
          | Unsuppress
          | TreeSync
          | HotEdit
          | NoConfirm
          | DryRun
          | Quiet
          | AURIgnore String
          | Ignore String
          | IgnoreGroup String
          | BuildPath FilePath
          | BuildUser String
          | ABCSort
          | TruncHead Int
          | TruncTail Int
          | DiffPkgbuilds
          | Devel
          | Customizepkg
          | KeepSource
          | Debug
          | CacheBackup
          | Clean
          | Abandon
          | ViewConf
          | RestoreState
          | NoPowerPill
          | IgnoreArch
          | Needed
          | Languages
          | Version
          | Help
          | JapOut
          | PolishOut
          | CroatianOut
          | SwedishOut
          | GermanOut
          | SpanishOut
          | PortuOut
          | FrenchOut
          | RussianOut
          | ItalianOut
          | SerbianOut
          | NorwegiOut
          | IndoOut
          | PacmanArg String String
            deriving (Eq, Ord, Show)

allFlags :: Language -> [OptDescr Flag]
allFlags lang = fold [ auraOperations lang
                     , auraOptions
                     , pacmanOptions
                     , dualOptions
                     , languageOptions
                     , longPacmanOptions ]

simpleOption :: (String, [String], Flag) -> OptDescr Flag
simpleOption (c, s, f) = Option c s (NoArg f) ""

auraOperations :: Language -> [OptDescr Flag]
auraOperations lang =
    [ Option "A" ["aursync"]   (NoArg AURInstall) (aurSy lang)
    , Option "B" ["save"]      (NoArg SaveState)  (saveS lang)
    , Option "C" ["downgrade"] (NoArg Cache)      (downG lang)
    , Option "L" ["viewlog"]   (NoArg LogFile)    (viewL lang)
    , Option "O" ["orphans"]   (NoArg Orphans)    (orpha lang) ]

auraOptions :: [OptDescr Flag]
auraOptions = Option [] ["aurignore"] (ReqArg AURIgnore "" ) "" :
              Option [] ["build"]     (ReqArg BuildPath "" ) "" :
              Option [] ["builduser"] (ReqArg BuildUser "" ) "" :
              Option [] ["head"] (OptArg (TruncHead . truncHandler) "") "" :
              Option [] ["tail"] (OptArg (TruncTail . truncHandler) "") "" :
              fmap simpleOption
              [ ( "a", ["delmakedeps"],  DelMDeps      )
              , ( [],  ["backup"],       CacheBackup   )
              , ( "c", ["clean"],        Clean         )
              , ( "d", ["deps"],         ViewDeps      )
              , ( "j", ["abandon"],      Abandon       )
              , ( "k", ["diff"],         DiffPkgbuilds )
              , ( "i", ["info"],         Info          )
              , ( "p", ["pkgbuild"],     GetPkgbuild   )
              , ( "q", ["quiet"],        Quiet         )
              , ( [],  ["restore"],      RestoreState  )
              , ( "s", ["search"],       Search        )
              , ( "t", ["treesync"],     TreeSync      )
              , ( "u", ["sysupgrade"],   Upgrade       )
              , ( "w", ["downloadonly"], Download      )
              , ( "x", ["unsuppress"],   Unsuppress    )
              , ( [],  ["abc"],          ABCSort       )
              , ( [],  ["allsource"],    KeepSource    )
              , ( [],  ["auradebug"],    Debug         )
              , ( [],  ["custom"],       Customizepkg  )
              , ( [],  ["devel"],        Devel         )
              , ( [],  ["hotedit"],      HotEdit       )
              , ( [],  ["ignorearch"],   IgnoreArch    )
              , ( [],  ["languages"],    Languages     )
              , ( [],  ["no-pp"],        NoPowerPill   )
              , ( [],  ["dryrun"],       DryRun        )
              , ( [],  ["viewconf"],     ViewConf      ) ]
    where truncHandler :: Maybe String -> Int
          truncHandler x = fromMaybe 10 (x >>= readMaybe)

-- These are intercepted Pacman flags. Their functionality is different.
pacmanOptions :: [OptDescr Flag]
pacmanOptions = fmap simpleOption
                [ ( "y", ["refresh"], Refresh )
                , ( "V", ["version"], Version )
                , ( "h", ["help"],    Help    ) ]

-- Options that have functionality stretching across both Aura and Pacman.
dualOptions :: [OptDescr Flag]
dualOptions = Option [] ["ignore"]      (ReqArg Ignore      "" ) "" :
              Option [] ["ignoregroup"] (ReqArg IgnoreGroup "" ) "" :
              fmap simpleOption
              [ ( [], ["noconfirm"], NoConfirm )
              , ( [], ["needed"],    Needed    ) ]

-- These Pacman options are ignored,
-- but parser needs to know that they require an argument
longPacmanOptions :: [OptDescr Flag]
longPacmanOptions = pacArg <$> zip
                    [ "dbpath", "root", "arch", "cachedir", "color"
                    , "config", "gpgdir" , "logfile", "assume-installed"
                    , "print-format" ]
                    ( "b" : "r" : repeat [] )
                    -- "owns" is apparently okay as is?
                    -- TODO: check all others
    where pacArg (option, letter) = Option letter [option]
                                    (ReqArg (PacmanArg option) "") ""

pacmanFlagMap :: FlagMap
pacmanFlagMap (PacmanArg option arg) = "--" <> option <> "=" <> arg
pacmanFlagMap _                      = ""

languageOptions :: [OptDescr Flag]
languageOptions = fmap simpleOption
                  [ ( [], ["japanese", "日本語"],      JapOut      )
                  , ( [], ["polish", "polski"],        PolishOut   )
                  , ( [], ["croatian", "hrvatski"],    CroatianOut )
                  , ( [], ["swedish", "svenska"],      SwedishOut  )
                  , ( [], ["german", "deutsch"],       GermanOut   )
                  , ( [], ["spanish", "español"],      SpanishOut  )
                  , ( [], ["portuguese", "português"], PortuOut    )
                  , ( [], ["french", "français"],      FrenchOut   )
                  , ( [], ["russian", "русский"],      RussianOut  )
                  , ( [], ["italian", "italiano"],     ItalianOut  )
                  , ( [], ["serbian", "српски"],       SerbianOut  )
                  , ( [], ["norwegian", "norsk"],      NorwegiOut  )
                  , ( [], ["indonesian"],              IndoOut     )
                  ]

-- `Hijacked` flags. They have original pacman functionality, but
-- that is masked and made unique in an Aura context.
hijackedFlagMap :: FlagMap
hijackedFlagMap = simpleFlagMap [ (CacheBackup,   "-b" )
                                , (Clean,         "-c" )
                                , (ViewDeps,      "-d" )
                                , (Info,          "-i" )
                                , (DiffPkgbuilds, "-k" )
                                , (RestoreState,  "-r" )
                                , (Search,        "-s" )
                                , (TreeSync,      "-t" )
                                , (Upgrade,       "-u" )
                                , (Download,      "-w" )
                                , (Refresh,       "-y" ) ]

-- These are flags which do the same thing in Aura or Pacman.
dualFlagMap :: FlagMap
dualFlagMap (Ignore      a) = "--ignore="      <> a
dualFlagMap (IgnoreGroup a) = "--ignoregroup=" <> a
dualFlagMap f = flip simpleFlagMap f [ (Quiet,     "-q"          )
                                     , (NoConfirm, "--noconfirm" )
                                     , (Needed,    "--needed"    ) ]

simpleFlagMap :: [(Flag, String)] -> Flag -> String
simpleFlagMap fm = fromMaybe "" . flip lookup fm

-- Converts the intercepted Pacman flags back into their raw string forms
-- and filters out the garbage.
reconvertFlags :: FlagMap -> [Flag] -> [String]
reconvertFlags fm = filter notNull . fmap fm

settingsFlags :: [Flag]
settingsFlags = [ Unsuppress, NoConfirm, HotEdit, DiffPkgbuilds, Debug, Devel
                , DelMDeps, Customizepkg, Quiet, NoPowerPill, KeepSource
                , ABCSort, IgnoreArch, DryRun, Needed ]

languageFlags :: [Flag]
languageFlags = [ JapOut, PolishOut, CroatianOut, SwedishOut, GermanOut
                , SpanishOut, PortuOut, FrenchOut, RussianOut, ItalianOut
                , SerbianOut, NorwegiOut, IndoOut ]

-- Flags like `AURIgnore` and `BuildPath` have args, and thus can't be included
-- in the `settingsFlags` list.
notSettingsFlag :: Flag -> Bool
notSettingsFlag (AURIgnore _)   = False
notSettingsFlag (BuildPath _)   = False
notSettingsFlag (BuildUser _)   = False
notSettingsFlag (TruncHead _)   = False
notSettingsFlag (TruncTail _)   = False
notSettingsFlag (PacmanArg _ _) = False
notSettingsFlag f               = f `notElem` (settingsFlags ++ languageFlags)

auraOperMsg :: Language -> String
auraOperMsg lang = usageInfo (yellow $ auraOperTitle lang) $ auraOperations lang

-- Extracts desirable results from given Flags.
-- Callers must supply an [alt]ernate value for when there are no matches.
fishOutFlag :: [(Flag, a)] -> a -> [Flag] -> a
fishOutFlag [] alt _             = alt
fishOutFlag ((f, r):fs) alt flags | f `elem` flags = r
                                 | otherwise      = fishOutFlag fs alt flags

getLanguage :: [Flag] -> Maybe Language
getLanguage = fishOutFlag flagsAndResults Nothing
    where flagsAndResults = zip languageFlags langFuns
          langFuns        = Just <$> [Japanese ..]

ignoredAuraPkgs :: [Flag] -> [String]
ignoredAuraPkgs [] = []
ignoredAuraPkgs (AURIgnore ps : _) = split ',' ps
ignoredAuraPkgs (_:fs) = ignoredAuraPkgs fs

buildPath :: [Flag] -> FilePath
buildPath [] = ""
buildPath (BuildPath p : _) = p
buildPath (_:fs) = buildPath fs

buildUser :: [Flag] -> Maybe String
buildUser [] = Nothing
buildUser (BuildUser u : _) = Just u
buildUser (_:fs) = buildUser fs

truncationStatus :: [Flag] -> Truncation
truncationStatus [] = None
truncationStatus (TruncHead n : _) = Head n
truncationStatus (TruncTail n : _) = Tail n
truncationStatus (_:fs) = truncationStatus fs

sortSchemeStatus :: [Flag] -> SortScheme
sortSchemeStatus = fishOutFlag [(ABCSort, Alphabetically)] ByVote

suppressionStatus :: [Flag] -> Bool
suppressionStatus = fishOutFlag [(Unsuppress, False)] True

delMakeDepsStatus :: [Flag] -> Bool
delMakeDepsStatus = fishOutFlag [(DelMDeps, True)] False

confirmationStatus :: [Flag] -> Bool
confirmationStatus = fishOutFlag [(NoConfirm, False)] True

neededStatus :: [Flag] -> Bool
neededStatus = fishOutFlag [(Needed, True)] False

hotEditStatus :: [Flag] -> Bool
hotEditStatus = fishOutFlag [(HotEdit, True)] False

pbDiffStatus :: [Flag] -> Bool
pbDiffStatus = fishOutFlag [(DiffPkgbuilds, True)] False

quietStatus :: [Flag] -> Bool
quietStatus = fishOutFlag [(Quiet, True)] False

rebuildDevelStatus :: [Flag] -> Bool
rebuildDevelStatus = fishOutFlag [(Devel, True)] False

customizepkgStatus :: [Flag] -> Bool
customizepkgStatus = fishOutFlag [(Customizepkg, True)] False

noPowerPillStatus :: [Flag] -> Bool
noPowerPillStatus = fishOutFlag [(NoPowerPill, True)] False

keepSourceStatus :: [Flag] -> Bool
keepSourceStatus = fishOutFlag [(KeepSource, True)] False

dryRunStatus :: [Flag] -> Bool
dryRunStatus = fishOutFlag [(DryRun, True)] False

makepkgFlags :: [Flag] -> [String]
makepkgFlags = fishOutFlag [(IgnoreArch, ["--ignorearch"])] []

parseLanguageFlag :: [String] -> (Maybe Language, [String])
parseLanguageFlag args =
    case getOpt Permute languageOptions args of
      (langs, nonOpts, _) -> (getLanguage langs, nonOpts)

-- I don't like this.
parseFlags :: Maybe Language -> [String] -> ([Flag], [String], [String])
parseFlags (Just lang) args = parseFlags' lang args
parseFlags Nothing     args = parseFlags' English args

-- Errors are dealt with manually in `aura.hs`.
parseFlags' :: Language -> [String] -> ([Flag], [String], [String])
parseFlags' lang args = case getOpt' Permute (allFlags lang) args of
                         (opts, nonOpts, pacOpts, _) -> (opts, nonOpts, pacOpts)
