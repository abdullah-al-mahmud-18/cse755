# Create Study Note from Project Files

Task - Create a comprehensive study notes on the project file topics.
When explaining a topic follow below rules
Rasterize the lecture pages and inspect them visually, not just text extraction. Slides carry diagrams, arrows, and layout meaning that plain text loses.
Do not begin writing until you have gone through every page in scope.
Explain in plain English. Assume you are explaining to an 8th grade student.
Explain equations in plain English like you are explaining to an 8th grade student.
Explain what each symbol in the equation stands for. Then explaining what the equation is saying.
Organize by lecture page
Produce a LaTeX file.
* No latex document setup code required. Start with \section{Name of the Lecture}
* Name of the lecture should be the only \section{}. All others should be \subsection or \subsubsection according to the document flow. 
* Minimal style. No colors, no boxes, no shaded backgrounds, no horizontal rules.
* No custom commands or macros. Built-in packages only (amsmath, amssymb, booktabs
if needed for tables).
* Preamble kept to the minimum needed to compile.
* Display math for anything longer than a single symbol; inline math otherwise.
* Tables allowed. If a cell's content is wide, break it across multiple lines so it
stays inside the margins.
* Sensible margins and a readable body size; nothing decorative.

Give me the latex file when it's done.