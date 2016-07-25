{-# language CPP #-}
{-# language QuasiQuotes #-}
{-# language TemplateHaskell #-}

module OpenCV.Core.Types.Mat.ToFrom
  ( MatShape
  , MatChannels
  , MatDepth
  , ToMat(..)
  , FromMat(..)
  ) where

import           "base" Data.Proxy ( Proxy(..) )
import           "base" Foreign.Storable ( Storable )
import           "base" GHC.TypeLits
import           "base" System.IO.Unsafe ( unsafePerformIO )
import qualified "inline-c" Language.C.Inline as C
import qualified "inline-c" Language.C.Inline.Unsafe as CU
import qualified "inline-c-cpp" Language.C.Inline.Cpp as C
import           "linear" Linear.Matrix ( M23, M33 )
import           "linear" Linear.V2 ( V2(..) )
import           "linear" Linear.V3 ( V3(..) )
import           "linear" Linear.V4 ( V4 )
import qualified "repa" Data.Array.Repa as Repa
import           "this" OpenCV.C.Inline ( openCvCtx )
import           "this" OpenCV.C.Types
import           "this" OpenCV.Core.Types.Mat.Internal
import           "this" OpenCV.Core.Types.Matx
import           "this" OpenCV.Core.Types.Mat.Repa
import           "this" OpenCV.Exception.Internal
import           "this" OpenCV.TypeLevel
import           "this" OpenCV.Unsafe


--------------------------------------------------------------------------------

C.context openCvCtx

C.include "opencv2/core.hpp"
C.using "namespace cv"

--------------------------------------------------------------------------------

type family MatShape    (a :: *) :: DS [DS Nat]
type family MatChannels (a :: *) :: DS Nat
type family MatDepth    (a :: *) :: DS *

type instance MatShape    (Mat shape channels depth) = shape
type instance MatChannels (Mat shape channels depth) = channels
type instance MatDepth    (Mat shape channels depth) = depth

type instance MatShape    (Matx depth m n) = 'S '[ 'S m, 'S n ] -- ShapeT '[m, n]
type instance MatChannels (Matx depth m n) = 'S 1
type instance MatDepth    (Matx depth m n) = 'S depth

type instance MatShape    (Vec depth dim) = 'S '[ 'S dim ] -- ShapeT '[dim]
type instance MatChannels (Vec depth dim) = 'S 1
type instance MatDepth    (Vec depth dim) = 'S depth

type instance MatShape    (M23 depth) = 'S '[ 'S 2, 'S 3 ] -- ShapeT [2, 3]
type instance MatChannels (M23 depth) = 'S 1
type instance MatDepth    (M23 depth) = 'S depth

type instance MatShape    (M33 depth) = 'S '[ 'S 3, 'S 3 ] -- ShapeT [3, 3]
type instance MatChannels (M33 depth) = 'S 1
type instance MatDepth    (M33 depth) = 'S depth

class ToMat a where
    toMat :: a -> Mat (MatShape a) (MatChannels a) (MatDepth a)

class FromMat a where
    fromMat :: Mat (MatShape a) (MatChannels a) (MatDepth a) -> a

instance ToMat   (Mat shape channels depth) where toMat   = id
instance FromMat (Mat shape channels depth) where fromMat = id

--------------------------------------------------------------------------------
-- Vec instances

#define TO_MAT(NAME)                                      \
instance ToMat NAME where {                               \
    toMat vec = unsafePerformIO $ fromPtr $               \
        withPtr vec $ \vecPtr ->                          \
          [CU.exp| Mat * {                                \
            new cv::Mat(*$(NAME * vecPtr), false)         \
          }|];                                            \
};

TO_MAT(Vec2i)
TO_MAT(Vec2f)
TO_MAT(Vec2d)
TO_MAT(Vec3i)
TO_MAT(Vec3f)
TO_MAT(Vec3d)
TO_MAT(Vec4i)
TO_MAT(Vec4f)
TO_MAT(Vec4d)

--------------------------------------------------------------------------------
-- Linear instances

instance (Storable depth) => FromMat (M23 depth) where
    fromMat = repaToM23 . toRepa

instance (Storable depth) => FromMat (M33 depth) where
    fromMat = repaToM33 . toRepa

repaToM23 :: (Storable e) => Repa.Array (M '[ 'S 2, 'S 3 ] 1) Repa.DIM3 e -> M23 e
repaToM23 a =
    V2 (V3 (i 0 0) (i 0 1) (i 0 2))
       (V3 (i 1 0) (i 1 1) (i 1 2))
  where
    i row col = Repa.unsafeIndex a $ Repa.ix3 0 col row

repaToM33 :: (Storable e) => Repa.Array (M '[ 'S 3, 'S 3 ] 1) Repa.DIM3 e -> M33 e
repaToM33 a =
    V3 (V3 (i 0 0) (i 0 1) (i 0 2))
       (V3 (i 1 0) (i 1 1) (i 1 2))
       (V3 (i 2 0) (i 2 1) (i 2 2))
  where
    i row col = Repa.unsafeIndex a $ Repa.ix3 0 col row

instance (ToDepth (Proxy depth), Storable depth)
      => ToMat (M23 depth) where
    toMat (V2 (V3 i00 i01 i02)
              (V3 i10 i11 i12)
          ) =
      exceptError $ withMatM
        (Proxy :: Proxy [2, 3])
        (Proxy :: Proxy 1)
        (Proxy :: Proxy depth)
        (pure 0 :: V4 Double) $ \imgM -> do
          unsafeWrite imgM [0, 0] i00
          unsafeWrite imgM [1, 0] i10
          unsafeWrite imgM [0, 1] i01
          unsafeWrite imgM [1, 1] i11
          unsafeWrite imgM [0, 2] i02
          unsafeWrite imgM [1, 2] i12

instance (ToDepth (Proxy depth), Storable depth)
      => ToMat (M33 depth) where
    toMat (V3 (V3 i00 i01 i02)
              (V3 i10 i11 i12)
              (V3 i20 i21 i22)
          ) =
      exceptError $ withMatM
        (Proxy :: Proxy [3, 3])
        (Proxy :: Proxy 1)
        (Proxy :: Proxy depth)
        (pure 0 :: V4 Double) $ \imgM -> do
          unsafeWrite imgM [0, 0] i00
          unsafeWrite imgM [1, 0] i10
          unsafeWrite imgM [2, 0] i20
          unsafeWrite imgM [0, 1] i01
          unsafeWrite imgM [1, 1] i11
          unsafeWrite imgM [2, 1] i21
          unsafeWrite imgM [0, 2] i02
          unsafeWrite imgM [1, 2] i12
          unsafeWrite imgM [2, 2] i22
