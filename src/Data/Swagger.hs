-- |
-- Swagger™ is a project used to describe and document RESTful APIs.
--
-- The Swagger specification defines a set of files required to describe such an API.
-- These files can then be used by the Swagger-UI project to display the API
-- and Swagger-Codegen to generate clients in various languages.
-- Additional utilities can also take advantage of the resulting files, such as testing tools.
module Data.Swagger (
  -- * How to use this library
  -- $howto

  -- ** @'Monoid'@ instances
  -- $monoids

  -- ** Lenses and prisms
  -- $lens

  -- ** Schema specification
  -- $schema

  -- * Re-exports
  module Data.Swagger.Lens,
  module Data.Swagger.ParamSchema,
  module Data.Swagger.Schema,

  -- * Swagger specification
  Swagger(..),
  Host(..),
  Scheme(..),

  -- ** Info types
  Info(..),
  Contact(..),
  License(..),

  -- ** PathItem
  PathItem(..),

  -- ** Operations
  Operation(..),
  Tag(..),
  TagName,

  -- ** Types and formats
  SwaggerType(..),
  Format,
  Definitions,
  CollectionFormat(..),

  -- ** Parameters
  Param(..),
  ParamAnySchema(..),
  ParamOtherSchema(..),
  ParamLocation(..),
  ParamName,
  Header(..),
  HeaderName,
  Example(..),

  -- ** Schemas
  ParamSchema(..),
  Schema(..),
  NamedSchema(..),
  SwaggerItems(..),
  Xml(..),

  -- ** Responses
  Responses(..),
  Response(..),
  HttpStatusCode,

  -- ** Security
  SecurityScheme(..),
  SecuritySchemeType(..),
  SecurityRequirement(..),

  -- *** API key
  ApiKeyParams(..),
  ApiKeyLocation(..),

  -- *** OAuth2
  OAuth2Params(..),
  OAuth2Flow(..),
  AuthorizationURL,
  TokenURL,

  -- ** External documentation
  ExternalDocs(..),

  -- ** References
  Reference(..),
  Referenced(..),

  -- ** Miscellaneous
  MimeList(..),
  URL(..),
) where

import Data.Swagger.Lens
import Data.Swagger.ParamSchema
import Data.Swagger.Schema

import Data.Swagger.Internal

-- $setup
-- >>> import Control.Lens
-- >>> import Data.Aeson
-- >>> import Data.Monoid
-- >>> import Data.Proxy
-- >>> import GHC.Generics
-- >>> :set -XDeriveGeneric
-- >>> :set -XOverloadedStrings
-- >>> :set -XOverloadedLists
-- >>> :set -fno-warn-missing-methods

-- $howto
--
-- This section explains how to use this library to work with Swagger specification.

-- $monoids
--
-- Virtually all types representing Swagger specification have @'Monoid'@ instances.
-- The @'Monoid'@ type class provides two methods — @'mempty'@ and @'mappend'@.
--
-- In this library you can use @'mempty'@ for a default/empty value. For instance:
--
-- >>> encode (mempty :: Swagger)
-- "{\"swagger\":\"2.0\",\"info\":{\"version\":\"\",\"title\":\"\"}}"
--
-- As you can see some spec properties (e.g. @"version"@) are there even when the spec is empty.
-- That is because these properties are actually required ones.
--
-- You /should/ always override the default (empty) value for these properties,
-- although it is not strictly necessary:
--
-- >>> encode mempty { _infoTitle = "Todo API", _infoVersion = "1.0" }
-- "{\"version\":\"1.0\",\"title\":\"Todo API\"}"
--
-- You can merge two values using @'mappend'@ or its infix version @('<>')@:
--
-- >>> encode $ mempty { _infoTitle = "Todo API" } <> mempty { _infoVersion = "1.0" }
-- "{\"version\":\"1.0\",\"title\":\"Todo API\"}"
--
-- This can be useful for combining specifications of endpoints into a whole API specification:
--
-- @
-- \-\- /account subAPI specification
-- accountAPI :: Swagger
--
-- \-\- /task subAPI specification
-- taskAPI :: Swagger
--
-- \-\- while API specification is just a combination
-- \-\- of subAPIs' specifications
-- api :: Swagger
-- api = accountAPI <> taskAPI
-- @

-- $lens
--
-- Since @'Swagger'@ has a fairly complex structure, lenses and prisms are used
-- to work comfortably with it. In combination with @'Monoid'@ instances, lenses
-- make it fairly simple to construct/modify any part of the specification:
--
-- >>> :{
-- encode $ (mempty :: Swagger)
--   & definitions .~ [ ("User", mempty & type_ .~ SwaggerString) ]
--   & paths .~
--     [ ("/user", mempty & get ?~ (mempty
--         & produces ?~ MimeList ["application/json"]
--         & at 200 ?~ ("OK" & _Inline.schema ?~ Ref (Reference "User"))
--         & at 404 ?~ "User info not found")) ]
-- :}
-- "{\"swagger\":\"2.0\",\"info\":{\"version\":\"\",\"title\":\"\"},\"definitions\":{\"User\":{\"type\":\"string\"}},\"paths\":{\"/user\":{\"get\":{\"responses\":{\"404\":{\"description\":\"User info not found\"},\"200\":{\"schema\":{\"$ref\":\"#/definitions/User\"},\"description\":\"OK\"}},\"produces\":[\"application/json\"]}}}}"
--
-- In the snippet above we declare an API with a single path @/user@. This path provides method @GET@
-- which produces @application/json@ output. It should respond with code @200@ and body specified
-- by schema @User@ which is defined in @'definitions'@ property of swagger specification.
-- Alternatively it may respond with code @404@ meaning that user info is not found.
--
-- For convenience, @swagger2@ uses /classy field lenses/. It means that
-- field accessor names can be overloaded for different types. One such
-- common field is @'description'@. Many components of a Swagger specification
-- can have descriptions, and you can use the same name for them:
--
-- >>> encode $ (mempty :: Response) & description .~ "No content"
-- "{\"description\":\"No content\"}"
-- >>> :{
-- encode $ (mempty :: Schema)
--   & type_       .~ SwaggerBoolean
--   & description ?~ "To be or not to be"
-- :}
-- "{\"type\":\"boolean\",\"description\":\"To be or not to be\"}"
--
-- @'ParamSchema'@ is basically the /base schema specification/ and many types contain it (see @'HasParamSchema'@).
-- So for convenience, all @'ParamSchema'@ fields are transitively made fields of the type that has it.
-- For example, you can use @'type_'@ to access @'SwaggerType'@ of @'Header'@ schema without having to use @'paramSchema'@:
--
-- >>> encode $ (mempty :: Header) & type_ .~ SwaggerNumber
-- "{\"type\":\"number\"}"
--
-- Additionally, to simplify working with @'Response'@, both @'Operation'@ and @'Responses'@
-- have direct access to it via @'at' code@. Example:
--
-- >>> :{
-- encode $ (mempty :: Operation)
--   & at 404 ?~ "Not found"
-- :}
-- "{\"responses\":{\"404\":{\"description\":\"Not found\"}}}"
--
-- You might've noticed that @'type_'@ has an extra underscore in its name
-- compared to, say, @'description'@ field accessor.
-- This is because @type@ is a keyword in Haskell.
-- A few other field accessors are modified in this way:
--
--    - @'in_'@, @'type_'@, @'default_'@ (as keywords);
--    - @'maximum_'@ and @'minimum_'@ (as conflicting with @Prelude@);
--    - @'enum_'@ (as conflicting with @Control.Lens@).

-- $schema
--
-- @'ParamSchema'@ and @'Schema'@ are the two core types for data model specification.
--
-- @'ParamSchema' t@ specifies all the common properties, available for every data schema.
-- The @t@ parameter imposes some restrictions on @type@ and @items@ properties (see @'SwaggerType'@ and @'SwaggerItems'@).
--
-- @'Schema'@ is used for request and response bodies and allows specifying objects
-- with properties in addition to what @'ParamSchema'@ provides.
--
-- In most cases you will have a Haskell data type for which you would like to
-- define a corresponding schema. To facilitate this use case
-- @swagger2@ provides two classes for schema encoding.
-- Both these classes provide means to encode /types/ as Swagger /schemas/.
--
-- @'ToParamSchema'@ is intended to be used for primitive API endpoint parameters,
-- such as query parameters, headers and URL path pieces.
-- Its corresponding value-encoding class is @'ToHttpApiData'@ (from @http-api-data@ package).
--
-- @'ToSchema'@ is used for request and response bodies and mostly differ from
-- primitive parameters by allowing objects/mappings in addition to primitive types and arrays.
-- Its corresponding value-encoding class is @'ToJSON'@ (from @aeson@ package).
--
-- While lenses and prisms make it easy to define schemas, it might be that you don't need to:
-- @'ToSchema'@ and @'ToParamSchema'@ classes both have default @'Generic'@-based implementations!
--
-- @'ToSchema'@ default implementation is also aligned with @'ToJSON'@ default implementation with
-- the only difference being for sum encoding. @'ToJSON'@ defaults sum encoding to @'defaultTaggedObject'@,
-- while @'ToSchema'@ defaults to something which corresponds to @'ObjectWithSingleField'@. This is due to
-- @'defaultTaggedObject'@ behavior being hard to specify in Swagger.
--
-- Here's an example showing @'ToJSON'@–@'ToSchema'@ correspondance:
--
-- >>> data Person = Person { name :: String, age :: Integer } deriving Generic
-- >>> instance ToJSON Person
-- >>> instance ToSchema Person
-- >>> encode (Person "David" 28)
-- "{\"age\":28,\"name\":\"David\"}"
-- >>> encode $ toSchema (Proxy :: Proxy Person)
-- "{\"required\":[\"name\",\"age\"],\"type\":\"object\",\"properties\":{\"age\":{\"type\":\"integer\"},\"name\":{\"type\":\"string\"}}}"
--

