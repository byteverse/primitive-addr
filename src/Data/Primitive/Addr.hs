{-# LANGUAGE CPP #-}
{-# LANGUAGE MagicHash #-}
{-# LANGUAGE UnboxedTuples #-}

{- FOURMOLU_DISABLE -}
-- | Primitive operations on machine addresses.
module Data.Primitive.Addr
  ( -- * Types
    Addr(..)
    -- * Address arithmetic
  , nullAddr
  , plusAddr
  , minusAddr
  , remAddr
  -- * Element access
  , indexOffAddr
  , readOffAddr
  , writeOffAddr
  -- * Block operations
  , copyAddr
#if __GLASGOW_HASKELL__ >= 708
  , copyAddrToByteArray
#endif
  , moveAddr
  , setAddr
  -- * Conversion
  , addrToInt
) where
{- FOURMOLU_ENABLE -}

import Control.Monad.Primitive
import Data.Primitive.ByteArray
import Data.Primitive.Types (Prim (..))
import Numeric (showHex)

import Foreign.Marshal.Utils
import GHC.Exts

#if __GLASGOW_HASKELL__ < 708
toBool# :: Bool -> Bool
toBool# = id
#else
toBool# :: Int# -> Bool
toBool# = isTrue#
#endif

-- | A machine address
data Addr = Addr Addr#

instance Show Addr where
  showsPrec _ (Addr a) =
    showString "0x" . showHex (fromIntegral (I# (addr2Int# a)) :: Word)

instance Eq Addr where
  Addr a# == Addr b# = toBool# (eqAddr# a# b#)
  Addr a# /= Addr b# = toBool# (neAddr# a# b#)

instance Ord Addr where
  Addr a# > Addr b# = toBool# (gtAddr# a# b#)
  Addr a# >= Addr b# = toBool# (geAddr# a# b#)
  Addr a# < Addr b# = toBool# (ltAddr# a# b#)
  Addr a# <= Addr b# = toBool# (leAddr# a# b#)

-- | The null address
nullAddr :: Addr
nullAddr = Addr nullAddr#

infixl 6 `plusAddr`, `minusAddr`
infixl 7 `remAddr`

-- | Offset an address by the given number of bytes
plusAddr :: Addr -> Int -> Addr
plusAddr (Addr a#) (I# i#) = Addr (plusAddr# a# i#)

{- | Distance in bytes between two addresses. The result is only valid if the
difference fits in an 'Int'.
-}
minusAddr :: Addr -> Addr -> Int
minusAddr (Addr a#) (Addr b#) = I# (minusAddr# a# b#)

-- | The remainder of the address and the integer.
remAddr :: Addr -> Int -> Int
remAddr (Addr a#) (I# i#) = I# (remAddr# a# i#)

{- | Read a value from a memory position given by an address and an offset.
The memory block the address refers to must be immutable. The offset is in
elements of type @a@ rather than in bytes.
-}
indexOffAddr :: (Prim a) => Addr -> Int -> a
{-# INLINE indexOffAddr #-}
indexOffAddr (Addr addr#) (I# i#) = indexOffAddr# addr# i#

{- | Read a value from a memory position given by an address and an offset.
The offset is in elements of type @a@ rather than in bytes.
-}
readOffAddr :: (Prim a, PrimMonad m) => Addr -> Int -> m a
{-# INLINE readOffAddr #-}
readOffAddr (Addr addr#) (I# i#) = primitive (readOffAddr# addr# i#)

{- | Write a value to a memory position given by an address and an offset.
The offset is in elements of type @a@ rather than in bytes.
-}
writeOffAddr :: (Prim a, PrimMonad m) => Addr -> Int -> a -> m ()
{-# INLINE writeOffAddr #-}
writeOffAddr (Addr addr#) (I# i#) x = primitive_ (writeOffAddr# addr# i# x)

{- | Copy the given number of bytes from the second 'Addr' to the first. The
areas may not overlap.
-}
copyAddr ::
  (PrimMonad m) =>
  -- | destination address
  Addr ->
  -- | source address
  Addr ->
  -- | number of bytes
  Int ->
  m ()
{-# INLINE copyAddr #-}
copyAddr (Addr dst#) (Addr src#) n =
  unsafePrimToPrim $ copyBytes (Ptr dst#) (Ptr src#) n

#if __GLASGOW_HASKELL__ >= 708
-- | Copy the given number of bytes from the 'Addr' to the 'MutableByteArray'.
--   The areas may not overlap. This function is only available when compiling
--   with GHC 7.8 or newer.
copyAddrToByteArray :: PrimMonad m
  => MutableByteArray (PrimState m) -- ^ destination
  -> Int -- ^ offset into the destination array
  -> Addr -- ^ source
  -> Int -- ^ number of bytes to copy
  -> m ()
{-# INLINE copyAddrToByteArray #-}
copyAddrToByteArray (MutableByteArray marr) (I# off) (Addr addr) (I# len) =
  primitive_ $ copyAddrToByteArray# addr marr off len
#endif

{- | Copy the given number of bytes from the second 'Addr' to the first. The
areas may overlap.
-}
moveAddr ::
  (PrimMonad m) =>
  -- | destination address
  Addr ->
  -- | source address
  Addr ->
  -- | number of bytes
  Int ->
  m ()
{-# INLINE moveAddr #-}
moveAddr (Addr dst#) (Addr src#) n =
  unsafePrimToPrim $ moveBytes (Ptr dst#) (Ptr src#) n

{- | Fill a memory block of with the given value. The length is in
elements of type @a@ rather than in bytes.
-}
setAddr :: (Prim a, PrimMonad m) => Addr -> Int -> a -> m ()
{-# INLINE setAddr #-}
setAddr (Addr addr#) (I# n#) x = primitive_ (setOffAddr# addr# 0# n# x)

-- | Convert an 'Addr' to an 'Int'.
addrToInt :: Addr -> Int
{-# INLINE addrToInt #-}
addrToInt (Addr addr#) = I# (addr2Int# addr#)
