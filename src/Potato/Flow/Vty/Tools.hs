{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE RecursiveDo     #-}

module Potato.Flow.Vty.Tools (
  Tool(..)
  , ToolWidgetConfig(..)
  , ToolWidget(..)
  , holdToolsWidget
) where

import           Relude

import           Potato.Flow.Controller
import           Potato.Flow.Vty.Common
import           Potato.Reflex.Vty.Helpers

import           Control.Monad.Fix
import           Control.Monad.NodeId

import           Reflex


data ToolWidgetConfig t = ToolWidgetConfig {
  _toolWidgetConfig_tool :: Dynamic t Tool
  , _toolWidgetConfig_widthDyn :: Dynamic t Int
}

data ToolWidget t = ToolWidget {
  _toolWidget_setTool :: Event t Tool
  , _toolWidget_heightDyn :: Dynamic t Int
}


--onlyIfBeh :: (Reflex t) => Event t a -> Behavior t Bool -> Event t a
--onlyIfBeh ev beh = fmapMaybe (\(b,e) -> if b then Just e else Nothing) $ attach beh ev


holdToolsWidget :: forall t m. (PostBuild t m, MonadWidget t m)
  => ToolWidgetConfig t
  -> m (ToolWidget t)
holdToolsWidget ToolWidgetConfig {..} = mdo

  (radioEvs, heightDyn) <- radioList (constDyn ["(v)select","(p)an","(b)ox","(l)ine","(t)extbox","pai(n)t"]) (fmap ((:[]) . fromEnum) _toolWidgetConfig_tool) (Just _toolWidgetConfig_widthDyn)
  let
    selectB = void $ ffilter (==0) radioEvs
    panB = void $ ffilter (==1) radioEvs
    boxB = void $ ffilter (==2) radioEvs
    lineB = void $ ffilter (==3) radioEvs
    textB = void $ ffilter (==4) radioEvs
    textareaB = void $ ffilter (==5) radioEvs

  let
    setTool = leftmost
      [Tool_Select <$ leftmost [selectB]
      , Tool_Pan <$ leftmost [panB]
      , Tool_Box <$ leftmost [boxB]
      , Tool_Line <$ leftmost [lineB]
      , Tool_Text <$ leftmost [textB]
      , Tool_TextArea <$ leftmost [textareaB]]
{-
  vLayoutPad 4 $ debugStream [
    never
    , fmapLabelShow "radio" $ radioEvs
    , fmapLabelShow "selected" $ fmap ((:[]) . fromEnum) (updated _toolWidgetConfig_tool)
    ]
-}


  return ToolWidget {
    _toolWidget_setTool = setTool
    , _toolWidget_heightDyn = heightDyn
  }

  {-
      keyPressEv k = flip push (_pFWidgetCtx_ev_input _toolWidgetConfig_pfctx) $ \vtyev -> do
        consuming <- sample _toolWidgetConfig_consumingKeyboard
        return $ if not consuming
          then case vtyev of
            V.EvKey (V.KChar k') [] | k' == k -> Just ()
            _                                 -> Nothing
          else Nothing
          -}
