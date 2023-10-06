            CASE WHEN instr(data_type, '(') = 0 THEN data_type
		    ELSE
		    substr(data_type,
			   1,
			   CASE
			       WHEN instr(data_type, '(') > 0 THEN
				   instr(data_type, '(')
			       ELSE
				   length(data_type)
			   END
		    ) ||'x' ||
		    CASE
			WHEN instr(data_type, ')') > 0 THEN
			    substr(data_type,
				   instr(data_type, ')'),
				   length(data_type))
			ELSE
			    NULL
		    END
            END
