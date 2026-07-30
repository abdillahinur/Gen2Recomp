local RecordValidation = {}

function RecordValidation.fail(kind, message, level)
  error(kind .. " record: " .. message, level or 3)
end

function RecordValidation.id(kind, value, field)
  if type(value) ~= "string" or value == "" then
    RecordValidation.fail(kind, (field or "id") .. " is required", 4)
  end
  return value
end

function RecordValidation.integer(
  kind,
  value,
  minimum,
  maximum,
  field
)
  if type(value) ~= "number" or value % 1 ~= 0
      or value < minimum or value > maximum then
    RecordValidation.fail(
      kind,
      ("%s must be an integer from %d to %d")
        :format(field, minimum, maximum),
      4
    )
  end
  return value
end

function RecordValidation.optionalInteger(
  kind,
  value,
  minimum,
  maximum,
  field,
  default
)
  if value == nil then return default end
  return RecordValidation.integer(
    kind,
    value,
    minimum,
    maximum,
    field
  )
end

function RecordValidation.array(kind, values, field, minimum)
  if type(values) ~= "table" or #values < (minimum or 0) then
    RecordValidation.fail(kind, field .. " must be an array", 4)
  end
  local result = {}
  for index, value in ipairs(values) do result[index] = value end
  return result
end

return RecordValidation
