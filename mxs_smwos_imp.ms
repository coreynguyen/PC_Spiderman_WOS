gc()
clearListener()
try(DestroyDialog smwos)catch(smwos)
rollout smwos "SMWOS" (
	
	struct fvf_t (
		unk12 = 0, -- channel? stop reading when =255
		pos = 0, 
		data = 0, 
		type = 0, 
		fn read f = (
			unk12 = readShort f #unsigned
			pos = readShort f #unsigned
			data = readShort f #unsigned
			type = readShort f #unsigned
			(unk12 != 255 and unk12 != undefined)
			)
		)
	
	struct mesh_t (
		
		-- skip 32 bytes
		/*uint32_t*/ count1 = 0,
		/*uint32_t*/ count2 = 0,
		/*uint32_t*/ count3 = 0,
		/*uint32_t*/ unk01 = 0,
		/*uint32_t*/ unk02 = 0,
		/*uint32_t*/ unk03 = 0,
		/*uint32_t*/ unk04 = 0,
		/*uint32_t*/ unk05 = 0,
		/*uint32_t*/ unk06 = 0,
		/*uint32_t*/ unk07 = 0,
		/*uint32_t*/ unk08 = 0,
		/*uint32_t*/ unk09 = 0,
		/*uint32_t*/ unk10 = 0,
		/*uint32_t*/ unk11 = 0,
		/*uint16_t[]*/ bone_pal = #(),
		-- pad bone_pal to alignment of 4 bytes
		
		/*uint32_t*/ magical_48 = 0,
		/*uint32_t*/ magical_num1 = 0,
		/*uint32_t*/ magical_num2 = 0,
		
		/*fvf_t[]*/ fvf = #(),
		
		-- entire block is padded to alignment of 16 bytes
		
		
		fn read f verbose:false = (
			
			local pos = ftell f
			
			if verbose do format "BEGPOS: %\n" (pos as integer)
			
			fseek f 32 #seek_cur
			
			count1 = readLong f
			count2 = readLong f
			count3 = readLong f -- ? bone pal count
			
			
			unk01 = readLong f
			unk02 = readLong f
			unk03 = readLong f
			unk04 = readLong f
			unk05 = readLong f
			unk06 = readLong f
			unk07 = readLong f
			unk08 = readLong f
			unk09 = readLong f
			unk10 = readLong f
			unk11 = readLong f
			
			if verbose do format "coun1: \t%\n" count1
			if verbose do format "coun2: \t%\n" count2
			if verbose do format "unk01: \t%\n" unk01
			if verbose do format "unk02: \t%\n" unk02
			if verbose do format "verts: \t%\n" unk03
			if verbose do format "unk04: \t%\n" unk04
			if verbose do format "unk05: \t%\n" unk05
			if verbose do format "unk06: \t%\n" unk06
			if verbose do format "faces: \t%\n" unk07
			if verbose do format "unk08: \t%\n" unk08
			if verbose do format "unk09: \t%\n" unk09
			if verbose do format "unk10: \t%\n" unk10
			if verbose do format "unk11: \t%\n" unk11
			
			bone_pal = for i = 1 to count3 collect readShort f
			
			fseek f (mod (4-(mod (bone_pal.count * 2) 4)) 4) #seek_cur
			
			magical_48 = readLong f
			magical_num1 = readLong f
			magical_num2 = readLong f -- should be 0?
			
			if verbose do format "stride: \t%\n" magical_48
			if verbose do format "_num1: \t%\n" magical_num1
			if verbose do format "_num2: \t%\n" magical_num2
			
			if verbose do format "FVFPOS: %\n" ((ftell f) as integer)
			fvf = #()
			local o = fvf_t()
			while o.unk12 != 255 do (
				o = fvf_t()
				if not o.read(f) do (
					exit
					)
				append fvf o
				)
			if verbose do print (fvf as string)
			if verbose do format "FVFCOUNT: \t%\n" fvf.count
			local end = (ftell f) - pos
			fseek f (mod (16-(mod end 16)) 16) #seek_cur
			
			
			if verbose do format "ENDPOS: %\n" ((ftell f) as integer)
			
			
			)
		
		)
	
	struct header_t (
		
		-- skip 24 bytes
		
		/*uint32_t*/ magical_count1 = 0,
		
		-- skip 20 bytes
		
		/*float[3]*/ bmin = [0.0, 0.0, 0.0],
		/*float[3]*/ bmax = [0.0, 0.0, 0.0],
		
		
		-- skip 20 bytes
		-- skip table (8 x magical_count1)
		
		/*mesh_t[]*/ meshes = #(),
		
		fn read f verbose:false = (
			
			
			-- skip the start 
			fseek f 24 #seek_cur
			
			magical_count1 = readlong f
			
			-- more non-sense!, skipping it
			fseek f 20 #seek_cur
			
			bmin = [readFloat f, readFloat f, readFloat f]
			bmax = [readFloat f, readFloat f, readFloat f]
			
			
			-- more non-sense!, skipping it
			fseek f 20 #seek_cur
			
			-- skip table
			fseek f (magical_count1 * 8) #seek_cur
			
			-- align cursor
			fseek f (mod (16-(mod (magical_count1 * 8) 16)) 16) #seek_cur
			
			-- read the meshes
			meshes = #()
			for m = 1 to magical_count1 do (
				if verbose do format "\nMesh%\n-----------------------------------\n" m
				local o = mesh_t()
				o.read f verbose:verbose
				append meshes o
				)
			
			)
		
		)
	
	fn read_half f = (
		local inputAsInt = readshort f #unsigned
		local sign = (bit.and (bit.shift inputAsInt -15) 0x00000001)
		local exponent = (bit.shift (bit.and inputAsInt 0x7C00) -10) as integer + 112
		local fraction = (bit.and inputAsInt 0x03FF)
		bit.intasfloat (
			(bit.or (bit.or (bit.shift fraction 13) (bit.shift exponent 23)) (bit.shift sign 31))
			)
		)
	
	fn read file verbose:true mscale:39.3701 = (
		
		if file != undefined and file != "" and MatchPattern file pattern:"*.component*.MESH" then (
			
			local fname = getFilenameFile (getFilenameFile file)
			local fpath = getFilenamePath file
			
			local header = fpath + fname + ".component0.MESH"
			local payload = fpath + fname + ".component1.MESH"
			
			if doesFileExist header and doesFileExist payload then (
				
				delete objects
				local f = try(fopen header "rb")catch(undefined)
				if f != undefined then (
					local hdr = header_t()
					hdr.read f verbose:verbose
					
					fclose f
					
					if hdr.magical_count1 > 0 then (
						
						f = try(fopen payload "rb")catch(undefined)
						if f != undefined then (
							local sscale = [hdr.bmax[1], hdr.bmax[3], hdr.bmax[2]]
							for submesh in hdr.meshes do (
								local vertArray = #()
								local boneIDs   = #()
								local weights   = #()
								local normals   = #()
								local uvs0      = #()
								local uvs1      = #()
								local colors    = #()
								local basePos = ftell f
								local stride = submesh.magical_48
	
								for v = 0 to (submesh.unk03 - 1) do (
									
									local val = #(0.0, 0.0, 0.0, 0.0)

									for fvf in submesh.fvf do (
										fseek f (basePos + v * stride + fvf.pos) #seek_set

										case fvf.data of (

											-- ==== BYTE-PACKED FORMATS ====
											0x04: ( -- 4 bytes, Color RGBA (unsigned bytes normalized)
												val = for i = 1 to 4 collect (readByte f #unsigned / 255.0)
												)
											0x05: ( -- 4 bytes, Bone Indices (unsigned bytes)
												val = for i = 1 to 4 collect (readByte f #unsigned)
												)
											0x08: ( -- 4 bytes, Weights (unsigned bytes normalized)
												val = for i = 1 to 4 collect (readByte f #unsigned / 255.0)
												)
											0x0F: ( -- 4 bytes, BYTE4N (signed bytes normalized)
												val = for i = 1 to 4 collect (readByte f #signed / 127.0)
												)
											
											-- ==== SHORT-PACKED FORMATS ====
											0x0A: ( -- 8 bytes, SHORT4N (signed shorts normalized)
												val = for i = 1 to 4 collect (readShort f #signed / 32767.0)
												)
											
											0x10: ( -- 8 bytes, Also SHORT4N (redundant?)
												val = for i = 1 to 4 collect (read_half f)
												)
											
											-- ==== FLOAT FORMATS (not yet seen in your data, but typical in DX9) ====
											0x00: ( -- 4 bytes, FLOAT1
												val = #(readFloat f, 0.0, 0.0, 0.0)
												)
											
											0x01: ( -- 8 bytes, FLOAT2
												val = #(readFloat f, readFloat f, 0.0, 0.0)
												)
											
											0x02: ( -- 12 bytes, FLOAT3
												val = #(readFloat f, readFloat f, readFloat f, 0.0)
												)
											
											0x03: ( -- 16 bytes, FLOAT4
												val = #(readFloat f, readFloat f, readFloat f, readFloat f)
												)
											
											-- ==== SHORT2 FORMAT (UVs, compressed coords) ====
											0x06: ( -- 4 bytes, SHORT2N (2 signed shorts normalized)
												val = #(readShort f #signed / 32767.0, readShort f #signed / 32767.0, 0.0, 0.0)
												)
											
											-- ==== UBYTE4 PACKED VECTOR ====
											0x07: ( -- 4 bytes, UBYTE4N
												val = for i = 1 to 4 collect (readByte f #unsigned / 255.0)
												)
											
											-- ==== Fallback ====
											default: (
												--print ("UNKNOWN VERTEX TYPE: \t0x" + (bit.IntAsHex fvf.data) + "\n")
												)
											)
										
										case fvf.type of (
											0x00: ( -- Position
												append vertArray ([val[1], -val[3], val[2]] * mscale * sscale)
												)
											0x01: ( -- Weight
												append weights val
												)
											0x02: ( -- Bone Index
												append boneIDs val
												)
											0x03: ( -- Normal
												append normals ([val[1], -val[3], val[2]])
												)
											0x05: ( -- UV0
												append uvs0 [val[1], val[2]]
												)
											0x06: ( -- UV1
												append uvs1 [val[1], val[2]]
												)
											0x0A: ( -- Color
												append colors val
												)
											default: (
												--print ("UNKNOWN COMPONENT TYPE: \t0x" + (bit.IntAsHex fvf.type) + "\n")
												)
											)
										)
									
									fseek f (basePos + (submesh.unk03 * stride)) #seek_set
									
									)

								if verbose do format "\nVerts: % | Normals: % | UVs: % | BoneIDs: % | Weights: %\n" vertArray.count normals.count uvs0.count boneIDs.count weights.count
								
								
								local face_pos = ftell f
								local faceArray = #()
								local fa,fb,fc,x=0,y
								local face_reset=true
								while x < submesh.unk07 do (
									x+=1
									if face_reset == true then (
										x+=2
										face_reset=false
							-- 			append g.matid matid
										fa = ((readshort f #unsigned)) + 1
										fb = ((readshort f #unsigned)) + 1
										fc = ((readshort f #unsigned)) + 1
										if bit.get x 1 == true then (
											append faceArray [fa,fc,fb]
											)
										else(
											append faceArray [fa,fb,fc]
											)
										)
									else(
										fa = fb
										fb = fc
										fc = readshort f #unsigned
										if fc<0xFFFF then (
											
											fc += 1
							-- 				append g.matid matid
											if bit.get x 1 == true then (
												append faceArray [fa,fc,fb]
												)
											else(
												append faceArray [fa,fb,fc]
										
												)
											)
										else(
											face_reset=true
											)
										)
									)
								local face_end = ftell f
								fseek f (mod (4-(mod (face_end - face_pos) 4)) 4) #seek_cur
								
								local msh = mesh vertices:vertArray faces:faceArray
								msh.backfacecull = on
								msh.displayByLayer = false
								msh.wirecolor = random (color 0 0 0) (color 255 255 255)
								)
							fclose f
							) else (format "failed to open file2\n")
						) else (format "No meshes?\n")
					) else (format "failed to open file\n")
				) else (format "failed to locate file pairs\n")
			) else (format "Invalid File Nanoclature\n")
		
		)
	)
smwos.read(
	"C:\\Users\\Corey\\Downloads\\blackcat\\s3_blackcat000.component0.MESH"
	"C:\\Users\\Corey\\Downloads\\blackcat\\s3_blackcat_claw000.component1.MESH"
	"C:\\Users\\Corey\\Downloads\\blackcat\\s1_wolverine000.component0.MESH"
	GetOpenFileName caption:"Open MESH" types: "Package (*.MESH)|*.component0.MESH|All files (*.*)|*.*|"
	)
