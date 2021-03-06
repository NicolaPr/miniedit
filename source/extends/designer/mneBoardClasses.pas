unit mneBoardClasses;
{$mode objfpc}{$H+}
{**
 * Mini Edit
 *
 * @license    GPL 2 (http://www.gnu.org/licenses/gpl.html)
 * @author    Zaher Dirkey <zaher at parmaja dot com>
 *}

interface

uses
  Messages, Forms, SysUtils, StrUtils, Variants, Classes, Controls, Graphics, Contnrs,
  LCLintf, LCLType, ExtCtrls,
  Dialogs, EditorEngine, EditorClasses, EditorOptions, SynEditHighlighter, SynEditSearch, SynEdit,
  DesignerBoard, mneBoardForms;

type

  { TBoardFile }

  TBoardFile = class(TEditorFile, IFileEditor)
  private
    FContents: TBoardForm;
    function GetContents: TBoardForm;
  protected
    property Contents: TBoardForm read GetContents;
    function GetControl: TWinControl; override;
    function GetIsReadonly: Boolean; override;
    procedure DoLoad(FileName: string); override;
    procedure DoSave(FileName: string); override;
  public
    destructor Destroy; override;
  end;

  { TBoardFileCategory }

  TBoardFileCategory = class(TFileCategory)
  protected
    function DoCreateHighlighter: TSynCustomHighlighter; override;
    procedure InitMappers; override;
    function GetIsText: Boolean; override;
  public
  end;

implementation

{ TBoardFile }

function TBoardFile.GetContents: TBoardForm;
begin
  if FContents = nil then
  begin
    FContents := TBoardForm.Create(Engine.Container);
    FContents.Parent := Engine.Container;
    FContents.Align := alClient;
  end;
  Result := FContents;
end;

function TBoardFile.GetControl: TWinControl;
begin
  Result := Contents;
end;

function TBoardFile.GetIsReadonly: Boolean;
begin
  Result := True;
end;

procedure TBoardFile.DoLoad(FileName: string);
begin
  //Contents.Board.Picture.LoadFromFile(FileName);
end;

procedure TBoardFile.DoSave(FileName: string);
begin
  //Contents.Board.Picture.SaveToFile(FileName);
end;

destructor TBoardFile.Destroy;
begin
  FreeAndNil(FContents);
  inherited Destroy;
end;

{ TBoardFileCategory }

function TBoardFileCategory.DoCreateHighlighter: TSynCustomHighlighter;
begin
  Result := nil;
end;

procedure TBoardFileCategory.InitMappers;
begin
end;

function TBoardFileCategory.GetIsText: Boolean;
begin
  Result := False;
end;

initialization
  with Engine do
  begin
    Categories.Add(TBoardFileCategory.Create(DefaultProject.Tendency, 'Board'));
    Groups.Add(TBoardFile, 'board', 'board', TBoardFileCategory, ['board'], [fgkAssociated, fgkExecutable, fgkBrowsable]);
  end;
end.

