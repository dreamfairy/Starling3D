package starling.extensions.md5.model
{
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.VertexBuffer3D;

	/**
	 * 网格数据
	 */
	public class MD5MeshData extends MeshDataBase
	{
		public var md5_triangle : Vector.<MD5Triangle>;
		public var md5_weight : Vector.<MD5Weight>;
		public var md5_vertex : Vector.<MD5Vertex>;
		
		public var num_verts : int;
		public var num_tris : int;
		public var num_weights : int;
		
		public function MD5MeshData()
		{
			md5_triangle = new Vector.<MD5Triangle>();
			md5_weight = new Vector.<MD5Weight>();
			md5_vertex = new Vector.<MD5Vertex>();
		}
		
		/**
		 * 获取UV
		 */
		public function getUv() : Vector.<Number>
		{
			var uvVec : Vector.<Number> = new Vector.<Number>();
			for each(var vert : MD5Vertex in md5_vertex)
			{
				uvVec.push(vert.uv_x, vert.uv_y);
			}
			
			return uvVec;
		}
		
		/**
		 * 获取顶点索引
		 */
		public function getIndex() : Vector.<uint>
		{
			var indexVec : Vector.<uint> = new Vector.<uint>();
			for each(var tri : MD5Triangle in md5_triangle)
			{
				indexVec = indexVec.concat(tri.indexVec);
			}
			
			return indexVec;
		}
		
		public var uvRawData : Vector.<Number>;
		public var indiceRawData : Vector.<uint>;
		public var vertexRawData : Vector.<Number>;
		public var jointIndexRawData : Vector.<Number>;
		public var jointWeightRawData : Vector.<Number>;
		
		public var uvBuffer : VertexBuffer3D;
		public var indiceBuffer : IndexBuffer3D;
		public var vertexBuffer : VertexBuffer3D;
		public var jointIndexBuffer : VertexBuffer3D;
		public var jointWeightBuffer : VertexBuffer3D;
	}
}