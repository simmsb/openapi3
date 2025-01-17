{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE LambdaCase #-}
-- |
-- Module:      Data.OpenApi.SchemaOptions
-- Maintainer:  Nickolay Kudasov <nickolay@getshoptv.com>
-- Stability:   experimental
--
-- Generic deriving options for @'ToParamSchema'@ and @'ToSchema'@.
module Data.OpenApi.SchemaOptions (
    SchemaOptions (..)
  , defaultSchemaOptions
  , fromAesonOptions
) where

import qualified Data.Aeson.Types as Aeson
import Data.Char

-- | Options that specify how to encode your type to Swagger schema.
data SchemaOptions = SchemaOptions
  { -- | Function applied to field labels. Handy for removing common record prefixes for example.
    fieldLabelModifier :: String -> String
    -- | Function applied to constructor tags which could be handy for lower-casing them for example.
  , constructorTagModifier :: String -> String
    -- | Function applied to datatype name.
  , datatypeNameModifier :: String -> String
    -- | If @'True'@ the constructors of a datatype, with all nullary constructors,
    -- will be encoded to a string enumeration schema with the constructor tags as possible values.
  , allNullaryToStringTag :: Bool
    -- | Hide the field name when a record constructor has only one field, like a newtype.
  , unwrapUnaryRecords :: Bool
    -- | Specifies how to encode constructors of a sum datatype.
  , sumEncoding :: Aeson.SumEncoding
    -- | If @'True'@ then don't mark types of omissable fields as nullable. To
    -- be used with 'Aeson.omitNothingFields' where a field omission is used to
    -- mark 'Nothing', instead of null.
  , setNullableOnOmissable :: Bool
  }

-- | Default encoding @'SchemaOptions'@.
--
-- @
-- 'SchemaOptions'
-- { 'fieldLabelModifier'     = id
-- , 'constructorTagModifier' = id
-- , 'datatypeNameModifier'   = id
-- , 'allNullaryToStringTag'  = True
-- , 'unwrapUnaryRecords'     = False
-- , 'sumEncoding'            = 'Aeson.defaultTaggedObject'
-- }
-- @
defaultSchemaOptions :: SchemaOptions
defaultSchemaOptions = SchemaOptions
  -- \x -> traceShowId x
  { fieldLabelModifier = id
  , constructorTagModifier = id
  , datatypeNameModifier = conformDatatypeNameModifier
  , allNullaryToStringTag = True
  , unwrapUnaryRecords = False
  , sumEncoding = Aeson.defaultTaggedObject
  , setNullableOnOmissable = False
  }


-- | According to spec https://github.com/OAI/OpenAPI-Specification/blob/main/versions/3.0.3.md#components-object 
-- name must conform to ^[a-zA-Z0-9\.\-_]+$
conformDatatypeNameModifier :: String -> String
conformDatatypeNameModifier = 
  foldl (\acc x -> acc ++ convertChar x) ""  
  where 
    convertChar = \case 
      c | isAlphaNum c || elem c "-._" -> [c]
      c -> "_" ++ (show $ ord c) ++ "_"

-- | Convert 'Aeson.Options' to 'SchemaOptions'.
--
-- Specifically the following fields get copied:
--
-- * 'fieldLabelModifier'
-- * 'constructorTagModifier'
-- * 'allNullaryToStringTag'
-- * 'unwrapUnaryRecords'
--
-- Note that these fields have no effect on `SchemaOptions`:
--
-- * 'Aeson.omitNothingFields'
-- * 'Aeson.tagSingleConstructors'
--
-- The rest is defined as in 'defaultSchemaOptions'.
--
-- @since 2.2.1
--
fromAesonOptions :: Aeson.Options -> SchemaOptions
fromAesonOptions opts = defaultSchemaOptions
  { fieldLabelModifier     = Aeson.fieldLabelModifier     opts
  , constructorTagModifier = Aeson.constructorTagModifier opts
  , allNullaryToStringTag  = Aeson.allNullaryToStringTag  opts
  , unwrapUnaryRecords     = Aeson.unwrapUnaryRecords     opts
  , sumEncoding            = Aeson.sumEncoding            opts
  , setNullableOnOmissable = Aeson.omitNothingFields      opts
  }
