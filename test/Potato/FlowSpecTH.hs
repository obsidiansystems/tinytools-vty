{-# LANGUAGE RankNTypes           #-}
{-# LANGUAGE RecordWildCards      #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE TemplateHaskell          #-}

module Potato.FlowSpecTH
  ( spec
  )
where

import           Relude hiding (Type)

import           Test.Hspec
import           Test.Hspec.Contrib.HUnit   (fromHUnitTest)
import           Test.HUnit

import           Potato.Flow.Vty.Main
import Potato.Flow

import qualified Graphics.Vty               as V
import           Reflex
import           Reflex.Host.Class
import           Reflex.Vty
import           Reflex.Vty.Test.Monad.Host
import           Reflex.Vty.Test.Monad.Host.TH
import Reflex.Vty.Test.Common

-- for reference, non-TH equivalent network
{-
data PotatoNetwork t (m :: Type -> Type)

instance (MonadVtyApp t (TestGuestT t m), TestGuestConstraints t m) => ReflexVtyTestApp (PotatoNetwork t m) t m where
  data instance VtyAppInputTriggerRefs (PotatoNetwork t m) = PotatoNetwork_InputTriggerRefs {
      -- force an event bypassing the normal interface
      _potatoNetwork_InputTriggerRefs_bypassEvent :: Ref m (Maybe (EventTrigger t WSEvent))
    }
  data instance VtyAppInputEvents (PotatoNetwork t m) = PotatoNetwork_InputEvents {
      _potatoNetwork_InputEvents_InputEvents_bypassEvent :: Event t WSEvent
    }

  data instance VtyAppOutput (PotatoNetwork t m) =
    PotatoNetwork_Output {
        _potatoNetwork_Output_exitEv :: Event t ()
      }
  getApp PotatoNetwork_InputEvents {..} = do
    exitEv <- mainPFWidget $ MainPFWidgetConfig {
        _mainPFWidgetConfig_initialFile = Nothing
        , _mainPFWidgetConfig_initialState = emptyOwlPFState
        , _mainPFWidgetConfig_bypassEvent = _potatoNetwork_InputEvents_InputEvents_bypassEvent
      }
    return PotatoNetwork_Output {
        _potatoNetwork_Output_exitEv = exitEv
      }

  makeInputs = do
    (ev, ref) <- newEventWithTriggerRef
    return (PotatoNetwork_InputEvents ev, PotatoNetwork_InputTriggerRefs ref)
-}

$(declareStuff "PotatoNetwork"
  [("bypassEvent", [t|WSEvent|])
    , ("moop", [t|Int|])]
  [("exitEv", [t|Event $(tv) ()|])]
  [|
      do
        exitEv <- mainPFWidgetWithBypass
          (MainPFWidgetConfig {
              _mainPFWidgetConfig_initialFile = Nothing
              , _mainPFWidgetConfig_initialState = emptyOwlPFState
              , _mainPFWidgetConfig_homeDirectory = ""
            })
          $(tinput "PotatoNetwork" "bypassEvent")

        return $ $(toutputcon "PotatoNetwork") exitEv

        -- you can also do it yourself
        --return ($(conE $ mkName "PotatoNetwork_Output") exitEv)

        -- splicing within record initializer does not seem to work :(
        --return $(ConT $ mkName "PotatoNetwork_Output") { $(VarE $ mkName "_potatoNetwork_Output_exitEv") = exitEv })
    |]
  )

-- DELETE
--data SomeData = SomeData { someField :: () }
-- $([d| y = SomeData { someField = () } |])
-- splicing inside quasi-quoted record initialization (i.e. RecordType { ... }) does not work
-- $([d| x = SomeData { $(VarE $ mkName "someField") = () } |])

test_basic :: Test
test_basic = TestLabel "open and quit" $ TestCase $ runSpiderHost $
  runReflexVtyTestApp @ (PotatoNetwork (SpiderTimeline Global) (SpiderHost Global)) (100,100) $ do

    -- get our app's input triggers
    PotatoNetwork_InputTriggerRefs {..} <- userInputTriggerRefs

    -- get our app's output events and subscribe to them
    PotatoNetwork_Output {..} <- userOutputs
    exitH <- subscribeEvent _potatoNetwork_Output_exitEv

    let
      readExitEv = sequence =<< readEvent exitH

    -- fire an empty event and ensure there is no quit event
    fireQueuedEventsAndRead readExitEv >>= \a -> liftIO (checkNothing a)

    -- close the annoying welcome popup
    queueVtyEvent (V.EvKey V.KEnter []) >> fireQueuedEvents

    -- drag mouse between layer and canvas panes to ensure GoatWidget mouse assumptions hold (otherwise it would crash)
    queueVtyEvent (V.EvMouseDown 0 10 V.BLeft []) >> fireQueuedEvents
    queueVtyEvent (V.EvMouseDown 1000 10 V.BLeft []) >> fireQueuedEvents
    queueVtyEvent (V.EvMouseUp 1000 10 (Just V.BLeft)) >> fireQueuedEvents
    queueVtyEvent (V.EvMouseDown 1000 10 V.BLeft []) >> fireQueuedEvents
    queueVtyEvent (V.EvMouseDown 0 10 V.BLeft []) >> fireQueuedEvents
    queueVtyEvent (V.EvMouseUp 0 10 (Just V.BLeft)) >> fireQueuedEvents

    -- enter quit sequence and ensure there is a quit event
    queueVtyEvent $ V.EvKey (V.KChar 'q') [V.MCtrl]
    fireQueuedEventsAndRead readExitEv >>= \a -> liftIO (checkSingleMaybe a ())

spec :: Spec
spec = do
  --fromHUnitTest $ TestLabel "Reifying..." $ TestCase $ liftIO $ putStrLn $(stringE . show =<< reifyInstances ''ReflexVtyTestApp [VarT $ mkName "a"])
  fromHUnitTest test_basic
