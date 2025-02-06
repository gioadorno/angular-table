#!/usr/bin/env fish

set prefix ""

# Prompt user to choose a project
function get_selection
    while true
        # Read the user's choice
        read -P "> " selection

        # Check if the input is valid (A/B/C)
        switch $selection
            case B b
                set selection "bacon"
                set prefix "kb"
                echo $selection
                break 
            case C c
                set selection "caveat"
                set prefix "pltn"
                echo $selection
                break 
            case M m
                set selection "monorepo"
                set prefix "gm"
                echo $selection
                break
            case Q q
                echo "Exiting program..."
                exit 0
            case '*'
                echo "Invalid choice. Please select A, B, or C. Press q to exit"
                continue
        end
    end
end


# Call the function and capture the result
        echo "Which project will this belong to?"
        echo "  B. Bacon"
        echo "  C. Caveat"
        echo "  M. Monorepo"
        echo "  Q. Exit"
set project (get_selection)
echo "Selected $project"

# Prompt user for component name
read -l -P "Please enter the component name: " component
if test -z "$component"
    echo "Component name cannot be empty."
    exit 1
end

# Prompt user for path
set path ""
if test "$project" = "monorepo"
        set path "libs/shared/gm-components/src/$component"
else
    read -l -P "Which directory will this component be built to (example - client-details/client-overview): " input
    while test -z "$input"
        read -l -P "Please enter a valid path. (example - client-details/client-overview): " input
    end
    set path "apps/$project/src/app/$input/$component"
end

# Ask if user wants to create columns
function create_columns --description 'Ask the user for confirmation' --argument prompt
    while true
        read -P "Do you wish to create columns? [Y/n]: " confirm

        switch $confirm
            case "" Y y 
                return 0
            case N n 
                return 1
        end 
    end 
end

# Create columns if yes
if create_columns; and true
    while true
        # Prompt for column name/key
        read -P "Enter column name: " column_name
        if test -z "$column_name"
            break
        end

        # Prompt for column display title
        read -P "Enter display title for $column_name: " display_title

        # Create column with key and title
        set column "{key: \"$column_name\", title: \"$display_title\"}"

        # Add column to array
        set columns $columns $column

                # Ask user if they want to add another column
        read -l -P "Do you want to add another column? (Y/n): " add_column
        set add_column (string lower $add_column)

        if test -z "$add_column"
            set add_column "y"
        end

        if test "$add_column" != "y"
            break
        end
    end
end

set columns_html
set displayed_columns
if test -n "$columns"
    for column in $columns
    set column_name (echo $column | sed -E 's/.*key: "([^"]+)".*/\1/')
    set column_title (echo $column | sed -E 's/.*title: "([^"]+)".*/\1/')
        echo $column_name

        set columns_html "$columns_html
        <ng-container matColumnDef=\"$column_name\">
            <th mat-header-cell *matHeaderCellDef>$column_title</th>
            <td mat-cell *matCellDef=\"let row\"></td>
        </ng-container>"

        # Add the column to displayedColumns array
        set displayed_columns "$displayed_columns, $column"
    end

        set displayed_columns (string join ", " $displayed_columns)
      echo $columns_html # Output the HTML
    echo $displayed_columns # Output the comma-separated column names
end

# Generate the component using nx g @nx/angular:component command
echo "Generating $component component..."
nx g @nx/angular:component "$path/$component" --no-interactive

# Wait for the files to be created
while not test -f "$path/$component.component.ts"; or not test -f "$path/$component.component.html"
    echo "Waiting for component files to be generated..."
    sleep 1
end

# Capitalize the first letter of the component name
set first_letter (string sub -s 1 -l 1 $component | string upper)
set rest (string sub -s 2 $component)
set className "$first_letter$rest"

# Override the html with code
echo "<mat-toolbar>
    <h1>$className</h1>
</mat-toolbar>
<mat-paginator 
    [length]=\"page.total\" 
    [pageIndex]=\"page.index\" 
    [pageSize]=\"page.size\"
    [pageSizeOptions]=\"page.options\"
    (page)=\"onPageChange(\$event)\"
>
</mat-paginator>
<table mat-table [dataSource]=\"dataSource.value()\" matSort matSortActive=\"created_at\" matSortDirection=\"desc\"
    matSortDisableClear>
$columns_html
    <tr mat-header-row *matHeaderRowDef=\"displayedColumns(); sticky: true\"></tr>
    <tr mat-row *matRowDef=\"let row; columns: displayedColumns()\"></tr>
    <tr class=\"mat-mdc-row\" *matNoDataRow>
        <td class=\"mdc-data-table__cell\">No data found</td>
    </tr>
</table>
<mat-paginator 
    [length]=\"page.total\" 
    [pageIndex]=\"page.index\" 
    [pageSize]=\"page.size\"
    [pageSizeOptions]=\"page.options\"
    (page)=\"onPageChange(\$event)\"
>
</mat-paginator>" > "$path/$component.component.html"

# Modify the TypeScript file with specific baseline
echo "import {
    Component,
    OnInit,
    viewChild,
    WritableSignal,
    signal,
    inject,
    Signal
} from '@angular/core';
import {MatToolbarModule} from '@angular/material/toolbar';
import {MatTableModule} from '@angular/material/table';
import {MatSort, MatSortModule, Sort} from '@angular/material/sort';
import {MatPaginatorModule, PageEvent} from '@angular/material/paginator';
import {ReactiveFormsModule} from '@angular/forms';
import {ActivatedRoute, Router} from '@angular/router';
import {toSignal} from '@angular/core/rxjs-interop';

@Component({
    selector: '$prefix-$component',
    standalone: true,
    imports: [
        MatToolbarModule,
        MatTableModule,
        MatSortModule,
        MatPaginatorModule,
        ReactiveFormsModule
    ],
    templateUrl: './$component.component.html',
    styleUrls: ['./$component.component.scss']
})
export class $className"Component" implements OnInit {
    private route = inject(ActivatedRoute);
    private router = inject(Router);
    
    readonly sort: Signal<MatSort | undefined> = viewChild(MatSort);
    private matSort: WritableSignal<Sort | null> = signal(null);

    public dataSource = signal([]);
    private queryParams = toSignal(this.route.queryParams);

    public displayedColumns = signal([$displayed_columns]);

    ngOnInit(): void {
        this.sort()?.sortChange.subscribe((s) => this.matSort.set(s));
    }

    onPageChange(event: PageEvent): void {
        this.router.navigate(['.'], {
            queryParams: { ...this.queryParams, page: event.pageIndex, size: event.pageSize },
            relativeTo: this.route,
        });
    }
}" > "$path/$component.component.ts"

# Output the component files
echo "Component files have been generated in $path"