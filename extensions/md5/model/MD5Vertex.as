package starling.extensions.md5.model
{
	import flash.geom.Vector3D;

	/**
	 * MD5顶点
	 */
	public class MD5Vertex
	{
		public var uv_x : Number;
		public var uv_y : Number;
		/**权重开始索引**/
		public var weight_index : Number = 0;
		/**权重数量**/
		public var weight_count : Number = 0;
		public var id : Number = 0;
		
		/**切线向量**/
		public var tangent : Vector3D;
	}
}