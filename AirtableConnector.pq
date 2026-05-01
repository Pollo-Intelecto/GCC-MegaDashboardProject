= (BASE_ID as text, TABLE_ID as text, VIEW_ID as text) =>
let 
    // Pagination Logic
    Pagination = List.Skip(
        List.Generate(
            () => [Page_Key = "init", Counter=0], 
            each [Page_Key] <> null, 
            each [
                Page_Key = try if [Counter] < 1 then "" else [WebCall][Value][offset] otherwise null, 
                WebCall = try if [Counter] < 1 then
                    // Initial API call without offset
                    Json.Document(
                        Web.Contents(
                            "https://api.airtable.com",
                            [
                                RelativePath = "v0/" & BASE_ID & "/" & TABLE_ID,
                                Query = [view = VIEW_ID],
                                Headers = [Authorization = "Bearer " & PERSONAL_ACCESS_TOKEN]
                            ]
                        )
                    )
                else
                    // Subsequent API calls with offset
                    Json.Document(
                        Web.Contents(
                            "https://api.airtable.com",
                            [
                                RelativePath = "v0/" & BASE_ID & "/" & TABLE_ID,
                                Query = [view = VIEW_ID, offset = [WebCall][Value][offset]],
                                Headers = [Authorization = "Bearer " & PERSONAL_ACCESS_TOKEN]
                            ]
                        )
                    ),
                Counter = [Counter] + 1 
            ],
            each [WebCall]
        ),
        1
    ),
    // Convert and Expand
    #"Converted to Table" = Table.FromList(Pagination, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"Value"}, {"Column1.Value"}),
    #"Expanded Column1.Value" = Table.ExpandRecordColumn(#"Expanded Column1", "Column1.Value", {"records"}, {"Column1.Value.records"}),
    #"Expanded Column1.Value.records" = Table.ExpandListColumn(#"Expanded Column1.Value", "Column1.Value.records"),
    #"Expanded Column1.Value.records1" = Table.ExpandRecordColumn(
        #"Expanded Column1.Value.records", "Column1.Value.records",
        {"id", "fields", "createdTime"},
        {"_airtableRecordId", "_airtableRecordFields", "_airtableRecordCreatedAt"}
    ),
    // Reorder columns
    #"Reordered Columns" = Table.ReorderColumns(
        #"Expanded Column1.Value.records1",
        {"_airtableRecordId", "_airtableRecordCreatedAt", "_airtableRecordFields"}
    ),
    // Buffer the table to prevent multiple API calls while determining column names
    BufferedTable = Table.Buffer(#"Reordered Columns"),
    
    // Get distinct field names without converting the whole table to records
    FieldNames = List.Distinct(
        List.Combine(
            List.Transform(
                Table.Column(BufferedTable, "_airtableRecordFields"), 
                each if _ <> null then Record.FieldNames(_) else {}
            )
        )
    ),
    // Expand using the efficiently generated list
    #"Expanded Record Fields" = Table.ExpandRecordColumn(
        BufferedTable, "_airtableRecordFields", 
        FieldNames, 
        FieldNames
    )
in
    #"Expanded Record Fields"
