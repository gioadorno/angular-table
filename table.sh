#!/bin/bash

# Prompt user for component name. Unused for now
# read -r -p "Project: " project
# if [[ -z "$project" ]]; then
#   echo "Project cannot be empty."
#   exit 1
# fi

# Prompt user for component name
read -r -p "Component name: " component
if [[ -z "$component" ]]; then
  echo "Component name cannot be empty."
  exit 1
fi

# Prompt user for path
read -r -p "Path (example - apps/projectname/src/app/shared/componentname): " path
if [[ -z "$path" ]]; then
  echo "Path cannot be empty."
  exit 1
fi

# Create directory structure if it doesn't exist
mkdir -p "$path"

# Generate the component using nx g @nx/angular:component command
echo "Generating $component component..."
nx g @nx/angular:component "$path/$component" --no-interactive

# Wait for the files to be created
while [[ ! -f "$path/$component.component.ts" || ! -f "$path/$component.component.html" ]]; do
  echo "Waiting for component files to be generated..."
  sleep 1
done

# Capitalize the first letter of the component name
className="$(tr '[:lower:]' '[:upper:]' <<<"${component:0:1}")${component:1}"

# Override the html with code
cat <<EOL >"$path/$component.component.html"
<mat-toolbar>
    <h1>$className</h1>
</mat-toolbar>
<mat-paginator 
    [length]="page.total" 
    [pageIndex]="page.index" 
    [pageSize]="page.size"
    [pageSizeOptions]="page.options"
    (page)="onPageChange(\$event)"
>
</mat-paginator>
<table mat-table [dataSource]="dataSource.value()" matSort matSortActive="created_at" matSortDirection="desc"
	matSortDisableClear>
	<tr mat-header-row *matHeaderRowDef="displayedColumns(); sticky: true"></tr>
	<tr mat-row *matRowDef="let row; columns: displayedColumns()"></tr>
	<tr class="mat-mdc-row" *matNoDataRow>
		<td class="mdc-data-table__cell">No data found</td>
	</tr>
</table>
<mat-paginator 
    [length]="page.total" 
    [pageIndex]="page.index" 
    [pageSize]="page.size"
    [pageSizeOptions]="page.options"
    (page)="onPageChange(\$event)"
>
</mat-paginator>
EOL

# Modify the TypeScript file with specific baseline
cat <<EOL >"$path/$component.component.ts"
import {
    Component,
    OnInit,
    ViewChild,
    WritableSignal,
    signal,
    inject
} from '@angular/core';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatTableModule } from '@angular/material/table';
import { MatSort, MatSortModule, Sort } from '@angular/material/sort';
import { MatPaginatorModule, PageEvent } from '@angular/material/paginator';
import { ReactiveFormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { toSignal } from '@angular/core/rxjs-interop';

@Component({
    selector: 'kb-$component',
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
export class ${className}Component implements OnInit {
    private route = inject(ActivatedRoute);
    private router = inject(Router);
    
    @ViewChild(MatSort) sort: MatSort;
    private matSort: WritableSignal<Sort | null> = signal(null);

    public dataSource = signal([]);
    private queryParams = toSignal(this.route.queryParams);
    private page = {
        total: 0,
        index: 0,
        size: 10,
        options: [10, 25, 50]
    };

    public displayedColumns = signal([]);

    ngOnInit(): void {
        this.sort.sortChange.subscribe((s) => this.matSort.set(s));
    }

    onPageChange(event: PageEvent): void {
        this.router.navigate(['.'], {
            queryParams: { ...this.queryParams, page: event.pageIndex, size: event.pageSize },
            relativeTo: this.route,
        });
    }
}
EOL

# Output the component files
echo "Component files have been generated in $path"
ls -l "$path"
