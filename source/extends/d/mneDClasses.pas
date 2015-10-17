unit mneDClasses;

{$mode objfpc}{$H+}
{**
 * Mini Edit
 *
 * @license    GPL 2 (http://www.gnu.org/licenses/gpl.html)
 * @author    Zaher Dirkey <zaher at parmaja dot com>
 *
 *}

interface

uses
  Messages, Forms, SysUtils, StrUtils, Variants, Classes, Controls, Graphics, Contnrs,
  LCLintf, LCLType,
  Dialogs, EditorOptions, SynEditHighlighter, SynEditSearch, SynEdit,
  Registry, EditorEngine, mnXMLRttiProfile, mnXMLUtils,
  SynEditTypes, SynCompletion, SynHighlighterHashEntries, EditorProfiles,
  SynHighlighterD,
  EditorDebugger, EditorClasses,
  mneClasses, mneConsoleClasses, mneConsoleForms, uTerminal;

type

  { TDFile }

  TDFile = class(TSourceEditorFile)
  protected
  public
    procedure NewContent; override;
    procedure OpenInclude; override;
    function CanOpenInclude: Boolean; override;
  end;

  { TDFileCategory }

  TDFileCategory = class(TTextFileCategory)
  private
    //procedure ExtractKeywords(Files, Variables, Identifiers: TStringList);
  protected
    procedure InitMappers; override;
    function DoCreateHighlighter: TSynCustomHighlighter; override;
  public
  end;

  TmneRunMode = (runConsole, runInternal, runProcess, runURL);

  { TDProjectOptions }

  TDProjectOptions = class(TEditorProjectOptions)
  private
    FExpandPaths: Boolean;
    FMainFile: string;
    FPaths: TStrings;
    FRunMode: TmneRunMode;
    procedure SetPaths(AValue: TStrings);
  public
    constructor Create; override;
    destructor Destroy; override;
    function CreateOptionsFrame(AOwner: TComponent; AProject: TEditorProject): TFrame; override;
  published
    property RunMode: TmneRunMode read FRunMode write FRunMode;
    property MainFile: string read FMainFile write FMainFile;
    property Paths: TStrings read FPaths write SetPaths;
    property ExpandPaths: Boolean read FExpandPaths write FExpandPaths;
  end;

  { TDTendency }

  TDTendency = class(TEditorTendency)
  private
    FCompiler: string;
  protected
    function CreateDebugger: TEditorDebugger; override;
    function CreateOptions: TEditorProjectOptions; override;
    procedure Init; override;
  public
    procedure Run; override;
    constructor Create; override;
    procedure Show; override;
  published
    property Compiler: string read FCompiler write FCompiler;
  end;

implementation

uses
  IniFiles, mnStreams, mnUtils, HTMLProcessor, SynEditStrConst, mneDConfigForms, mneDProjectFrames;

{ TDProject }

procedure TDProjectOptions.SetPaths(AValue: TStrings);
begin
  FPaths.Assign(AValue);
end;

constructor TDProjectOptions.Create;
begin
  inherited;
  FPaths := TStringList.Create;
end;

destructor TDProjectOptions.Destroy;
begin
  FreeAndNil(FPaths);
  inherited Destroy;
end;

function TDProjectOptions.CreateOptionsFrame(AOwner: TComponent; AProject: TEditorProject): TFrame;
begin
  Result := TDProjectFrame.Create(AOwner);
  TDProjectFrame(Result).Project := AProject;
end;

{ TDFile }

procedure TDFile.NewContent;
begin
  SynEdit.Text := cDSample;
end;

{ TDFile }

procedure TDFile.OpenInclude;
var
  P: TPoint;
  Attri: TSynHighlighterAttributes;
  aToken: string;
  aTokenType: integer;
  aStart: integer;

  function TryOpen: boolean;
  begin
    if (aToken[1] = '/') or (aToken[1] = '\') then
      aToken := RightStr(aToken, Length(aToken) - 1);
    aToken := Engine.ExpandFile(aToken);
    Result := FileExists(aToken);
    if Result then
      Engine.Files.OpenFile(aToken);
  end;

begin
  inherited;
  if Engine.Files.Current <> nil then
  begin
    if Engine.Files.Current.Group.Category is TDFileCategory then
    begin
      P := SynEdit.CaretXY;
      SynEdit.GetHighlighterAttriAtRowColEx(P, aToken, aTokenType, aStart, Attri);
      aToken := DequoteStr(aToken);
      //if (aToken <> '') and (TtkTokenKind(aTokenType) = tkString) then
      begin
        aToken := StringReplace(aToken, '/', '\', [rfReplaceAll, rfIgnoreCase]);
        if not TryOpen then
        begin
          aToken := ExtractFileName(aToken);
          TryOpen;
        end;
      end;
    end;
  end;
end;

function TDFile.CanOpenInclude: Boolean;
var
  P: TPoint;
  Attri: TSynHighlighterAttributes;
  aToken: string;
  aTokenType: integer;
  aStart: integer;
begin
  Result := False;
  if (Group <> nil) then
  begin
    if Group.Category is TDFileCategory then
    begin
      P := SynEdit.CaretXY;
      aToken := '';
      SynEdit.GetHighlighterAttriAtRowColEx(P, aToken, aTokenType, aStart, Attri);
      //Result := (aToken <> '') and (TtkTokenKind(aTokenType) = tkString);
    end;
  end;
end;

function CreateInernalConsole(Command, Params: string): TConsoleForm;
var
  aControl: TConsoleForm;
  thread: TConsoleThread;
begin
  aControl := TConsoleForm.Create(Application);
  aControl.Parent := Engine.Container;
  Engine.Files.New('CMD', aControl);

  aControl.CMDBox.Font.Color := Engine.Options.Profile.Attributes.Whitespace.Foreground;
  aControl.CMDBox.BackGroundColor := Engine.Options.Profile.Attributes.Whitespace.Background;
  aControl.ContentPanel.Color := aControl.CMDBox.BackGroundColor;

  aControl.CMDBox.Font.Name := Engine.Options.Profile.FontName;
  aControl.CMDBox.Font.Size := Engine.Options.Profile.FontSize;

  aControl.CMDBox.TextColor(Engine.Options.Profile.Attributes.Whitespace.Foreground);
  aControl.CMDBox.TextBackground(Engine.Options.Profile.Attributes.Whitespace.Background);
  aControl.CMDBox.Write('Ready!'#13#10);
  //aControl.CMDBox.InputSelColor
  thread := CreateConsoleThread;
  thread.CmdBox := aControl.CmdBox;
  thread.Shell := Command + ' '+ Params ;
  thread.Resume;

  Result := aControl;
  Engine.UpdateState([ecsRefresh]);
end;

{ TDTendency }

procedure TDTendency.Run;
var
  aFile: string;
  aRoot: string;
  aCompiler: string;
  aParams: string;
  s: string;
  i: Integer;
  aPath: string;
  Options: TDProjectOptions;
begin
  //if (Engine.Files.Current <> nil) and (fgkExecutable in Engine.Files.Current.Group.Kind) then
  Options := nil;

  if (Engine.Session.IsOpened) then
  begin
    Options := (Engine.Session.Project.Options as TDProjectOptions);
    aRoot := Engine.Session.GetRoot;
    aFile := ExpandToPath(Options.MainFile, aRoot);
  end;
  if (aFile = '') and (Engine.Files.Current <> nil) and (fgkExecutable in Engine.Files.Current.Group.Kind) then
    aFile := Engine.Files.Current.Name;
  if (aRoot = '') then
    aRoot := ExtractFileDir(aFile);

  if aFile <> '' then
  begin
    aCompiler := Compiler;
    if aCompiler = '' then
      aCompiler := 'rdmd.exe';

    aParams := '';
    for i := 0 to Options.Paths.Count - 1 do
    begin
      aPath := Trim(Options.Paths[i]);
      if aPath <>'' then
      begin
        if Options.ExpandPaths then
          aPath := Engine.ExpandFile(aPath);
        aParams := aParams + '-I' +aPath + ' ';
      end;
    end;
    aParams := aParams + aFile;

    {$ifdef windows}
    SetCurrentDir(aRoot);
    if Options.RunMode = runConsole then
    begin
      ExecuteProcess('cmd ', '/c "'+ aCompiler + ' ' + aParams + '" & pause', []);
    end
    else if Options.RunMode = runInternal then
    begin
      CreateInernalConsole(aCompiler, aParams)
    end;
    {$endif}

    {$ifdef linux}
    {$endif}

    {$ifdef macos}
    {$endif}
  end;
end;

constructor TDTendency.Create;
begin
  inherited Create;
end;

procedure TDTendency.Show;
begin
  with TDConfigForm.Create(Application) do
  begin
    FTendency := Self;
    Retrieve;
    if ShowModal = mrOK then
    begin
      Apply;
    end;
  end;
end;

function TDTendency.CreateDebugger: TEditorDebugger;
begin
  Result := nil;
end;

function TDTendency.CreateOptions: TEditorProjectOptions;
begin
  Result := TDProjectOptions.Create;
end;

procedure TDTendency.Init;
begin
  FCapabilities := [capRun, capCompile, capLink, capProjectOptions, capOptions];
  FTitle := 'D Lang';
  FDescription := 'D Files, *.D, *.inc';
  FName := 'D';
  FImageIndex := -1;
  AddGroup('D', 'html');
  AddGroup('html', 'html');
  AddGroup('css', 'css');
  AddGroup('js', 'js');
end;

{ TDFileCategory }

function TDFileCategory.DoCreateHighlighter: TSynCustomHighlighter;
begin
  Result := TSynDSyn.Create(nil);
end;

{procedure TDFileCategory.DoAddCompletion(AKeyword: string; AKind: integer);
begin
  Completion.ItemList.Add(AKeyword);
end;}

procedure TDFileCategory.InitMappers;
begin
  with Highlighter as TSynDSyn do
  begin
    Mapper.Add(WhitespaceAttri, attWhitespace);
    Mapper.Add(CommentAttri, attComment);
    Mapper.Add(KeywordAttri, attKeyword);
    Mapper.Add(DocumentAttri, attDocument);
    Mapper.Add(ValueAttri, attValue);
    Mapper.Add(FunctionAttri, attStandard);
    Mapper.Add(IdentifierAttri, attIdentifier);
    Mapper.Add(HtmlAttri, attOutter);
    Mapper.Add(TextAttri, attText);
    Mapper.Add(NumberAttri, attNumber);
    Mapper.Add(StringAttri, attString);
    Mapper.Add(SymbolAttri, attSymbol);
    Mapper.Add(VariableAttri, attVariable);
    Mapper.Add(ProcessorAttri, attDirective);
  end;
end;

initialization
  with Engine do
  begin
    Categories.Add(TDFileCategory.Create('D', [fckPublish]));

    Groups.Add(TDFile, 'D', 'D Files', 'D', ['d', 'inc'], [fgkAssociated, fgkExecutable, fgkMember, fgkBrowsable, fgkMain]);

    Tendencies.Add(TDTendency);
  end;
end.
