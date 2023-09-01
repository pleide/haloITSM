Import-Module HaloAPI

function Get-HaloCustomTableData {
    param (
        [Parameter(Mandatory=$true)]
        [String]$ticketId,
        [Parameter(Mandatory=$true)]
        [Int32]$tableCfId
    )

    $ticket = Get-HaloTicket -TicketId $ticketid

    $ticket = $ticket | Select Id, CustomFields
    $columns = $ticket.customfields | Where { $_.id -eq $tableCfId } | ForEach-Object { $_.value[0].customfields } | Select id, name, label
    $ticket.customfields = @($ticket.customfields | Where { $_.id -eq $tableCfId } | Select id, value)
    $ticket.customfields.value | ForEach-Object { $_.CustomFields = $_.CustomFields | Select id, value }

    [String]$newRowCode = '$newRowInfo = [PSCustomObject]@{'
    foreach ($column in $columns) {
        <# $column is the current item #>
        $newRowCode += "`n`t $($Column.Name) = 'Value'"
    }
    $newRowCode += "`n}"

    $tableInfo = [PSCustomObject]@{
        Columns = $columns
        Ticket = $ticket
        NewRowCode = $newRowCode
    }

    return $tableInfo

}

function Add-HaloCustomTableRow {
    param (
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$ticketObject,
        [Parameter(Mandatory=$true)]
        [PSCustomObject[]]$newRowData,
        [Parameter(Mandatory=$true)]
        [Array]$columnInfo
    )

    foreach ($newRow in $newRowData) {
        $rowFields = [System.Collections.ArrayList] @()
        foreach ($field in ($newrow | Get-Member -Type Properties | Select Name).Name) {
            $fieldObject = [PSCustomObject]@{
                id = ($columnInfo | Where { $_.name -eq $field }).id
                Value = $newRow.$field
            }
            $rowFields.Add($fieldObject) | Out-Null
        }

        $ids = ($ticketObject.customfields.value).id
        $newRowObject = [PSCustomObject] @{
            id = [Int32]((($ticketObject.customfields.value).id | Measure -Maximum).Maximum + 1)
            fkid = $ticketObject.id
            customFields = $rowFields
        }

        $ticketObject.customfields[0].value += $newRowObject
    }

    Return $ticketObject
}

$ticketId = "00000"
$tableCfId = "000"

$tableData = Get-HaloCustomTableData -ticketId $ticketId -tableCfId $tableCfId

#*┌────────────────────────────────────────────────────────────────────┐
#*│ Create a PSCustomObject for the information you need               │
#*│   to add to your custom table.                                     │
#*│                                                                    │
#*│ The output from Get-HaloCustomTableData includes a string property │
#*│   that can be copied from the terminal as a template object.       │
#*└────────────────────────────────────────────────────────────────────┘

$newRowInfo = [PSCustomObject]@{}

$tableData.Ticket = Add-HaloCustomTableRow -ticketObject $tableData.ticket -newRowData $newRowInfo -columnInfo $tableData.Columns
$body = @($tableData.ticket)
$jsonBody = ConvertTo-Json $body -Depth 10

$baseUri = "https://XXXXXXXXXXXX.haloitsm.com/api/"
$uri = $baseUri + "Tickets"

$RequestParams = @{
    Method = "POST"
    Uri = $uri
    Body = $jsonBody
}
$results = Invoke-HaloRequest $RequestParams
