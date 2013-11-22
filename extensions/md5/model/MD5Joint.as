package starling.extensions.md5.model
{
	import flash.geom.Matrix3D;
	
	import starling.extensions.md5.model.IJoint;

	/**
	 * 关节
	 */
	public class MD5Joint implements IJoint
	{
		//初始及动画位置矩阵
		public var bindPose : Matrix3D;
		
		//平移和旋转矩阵的转制矩阵
		public var inverseBindPose : Matrix3D;
		
		public var name : String = "";
		
		public var parentIndex : int = 0;
	}
}